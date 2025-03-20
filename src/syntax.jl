# SPDX-FileCopyrightText: © 2025 TEC <contact@tecosaur.net>
# SPDX-License-Identifier: MPL-2.0

"""
    Kind(name::String, tag::UInt8 = 0;
         start::Bool = false, stop::Bool = false)

A type tag for one or more Org elements. A `Kind` is a known Org syntax type,
such as a `"block"` that may also specify that it is the beginning or end of the
syntax structure (via the `start` and `stop` flags). A small amount of syntactic
metadata can be stored in the `tag` field. This is used to distinguish between
blocks with different names, for example.

This type has been optimised to fit all of this information into a single 64-bit bit
type, structured like so:

```
╭╌╌tag╌╌╮ ╭╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌syntax╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╮
┌┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┐
└┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┘
        ╰┄╯╴begin/end flag
```

The `name` may also identify a group of kinds, instead of a single kind.
Defined groups are:
- `"all"`
- `"elements"`
- `"greater_elements"`
- `"lesser_elements"`
- `"lesser_blocks"`
- `"objects"`
- `"minimal_objects"`
- `"standard_objects"`
- `"link"`
- `"script"`
- `"markup"`
- `"#+"` (elements that start with `#+...`)

See also: `K""`, `isbegin`, `isend`, `tag`, `plain`.

# Extended help

The `tag` byte were specifically motivated by headings and items, but are
available for all kinds and so have been employed for a wide range of purposes
whenever there is some sort of useful information that can be stored.

These syntax types use the `tag` byte like so:
- `heading`: the level of the heading
- `block`: a small hash of the block name
- `dynamic_block`: a small hash of the block name
- `keyword`: a small hash of the keyword
- `item`: the indentation level of the item
- `planning`: three bits are used to indicate exitance of each kind of planning.
- `entity`: a small hash of the entity name
- `export_snippet`: a small hash of the snippet format
- `footnote_reference`: the type of footnote reference
  - `1` is a label-only reference
  - `2` is a definition-only reference
  - `3` is a label and definition reference
"""
primitive type Kind 64 end
# 53 kinds + 1 special + 2 flags + 8-bit tag = 64 bits

"""
    kind_number(name::Symbol) -> Union{UInt8, Nothing}

Return the index of `name` in the `KIND_NAMES` tuple, ignoring
group markers. If `name` is not found, return `nothing`.
"""
function kind_number(name::Symbol)
    name == Symbol("") && return 0x00
    idx = findfirst(==(name), KIND_NAMES)
    isnothing(idx) && return
    mkrs = findlast(m -> first(m) < idx, KIND_MARKER_OFFSETS)::Int
    moff = last(KIND_MARKER_OFFSETS[mkrs])
    (idx - moff) % UInt8
end

function kind_number(k::Kind)
    (1 + trailing_zeros(reinterpret(UInt64, k))) % UInt8
end

Base.:(|)(k1::Kind, k2::Kind) =
    reinterpret(Kind, reinterpret(UInt64, k1) | reinterpret(UInt64, k2))

Base.:(&)(k1::Kind, k2::Kind) =
    reinterpret(Kind, reinterpret(UInt64, k1) & reinterpret(UInt64, k2))

Base.xor(k1::Kind, k2::Kind) =
    reinterpret(Kind, reinterpret(UInt64, k1) ⊻ reinterpret(UInt64, k2))

function Base.:(!)(k::Kind)
    ku = reinterpret(UInt64, k)
    reinterpret(Kind, (ku & KIND_SPECIAL) | (KIND_NOSPECIAL & ~ku))
end

function Base.:(~)(k::Kind)
    ku = reinterpret(UInt64, k)
    reinterpret(Kind, ku ⊻ KIND_SPECIAL)
end

function Base.in(k::Kind, kset::Kind)
    ku = reinterpret(UInt64, k)
    ksu = reinterpret(UInt64, kset)
    kmask = ifelse(ksu & (KIND_BEGIN | KIND_END) == 0, KIND_NOSPECIAL, KIND_NOTAG)
    km = ku & kmask
    km & ksu == km
end

Base.isempty(k::Kind) =
    iszero(reinterpret(UInt64, k) & KIND_NOSPECIAL)

Base.length(k::Kind) =
    count_ones(reinterpret(UInt64, k) & KIND_NOSPECIAL)

Base.eltype(::Type{Kind}) = Kind

function Base.iterate(k::Kind, from::Int = 0)
    ku = reinterpret(UInt64, k) & KIND_NOSPECIAL
    from >= 64 - leading_zeros(ku) && return
    ku = ku >> from
    skip = trailing_zeros(ku)
    ku = ku >> skip
    from += skip
    ku = ku & 0x0000000000000001
    ku = ku << from
    reinterpret(Kind, ku), from + 1
end

const KIND_BEGIN = UInt64(1) << 55
const KIND_END   = UInt64(1) << 54
const KIND_NOTAG = ~(UInt64(0xff) << 56)
const KIND_NOSPECIAL = ~(KIND_BEGIN | KIND_END) & KIND_NOTAG
const KIND_SPECIAL = ~KIND_NOSPECIAL

isbegin(k::Kind) = reinterpret(UInt64, k) & KIND_BEGIN != 0
isend(k::Kind)   = reinterpret(UInt64, k) & KIND_END != 0
tag(k::Kind)     = (reinterpret(UInt64, k) >> 56) % UInt8
plain(k::Kind)   = reinterpret(Kind, reinterpret(UInt64, k) & KIND_NOSPECIAL)

function settag(k::Kind, tag::UInt8)
    ku = reinterpret(UInt64, k)
    ku &= ~(UInt64(0xff) << 56)
    ku |= UInt64(tag) << 56
    reinterpret(Kind, ku)
end

const KIND_NAMES = (
    :_begin_all,
        :_begin_elements,
            :section,
            :heading,
            :_begin_greater_elements,
                :block,
                :dynamic_block,
                :drawer,
                :property_drawer,
                :list,
                :item,
                :table,
                :footnote_definition,
                # :inline_task, # EXCLUDED
            :_end_greater_elements,
            :_begin_lesser_elements,
                :_begin_lesser_blocks,
                    :comment_block,
                    :example_block,
                    :export_block,
                    :source_block,
                    :verse_block,
                :_end_lesser_blocks,
                :clock,
                :diarysexp,
                :planning,
                :comment,
                :fixedwidth,
                :hrule,
                :keyword,
                :latex_environment,
                :node_property,
                :table_row,
                :paragraph,
            :_end_lesser_elements,
        :_end_elements,
        :_begin_objects,
            :entity,
            :latex_fragment,
            :export_snippet,
            :footnote_reference,
            :citation,
            :citation_reference,
            :inline_call,
            :inline_source,
            :linebreak,
            :_begin_link,
                :radio_link,
                :plain_link,
                :angle_link,
                :regular_link,
            :_end_link,
            :macro,
            :target,
            :radio_target,
            :statistics_cookie,
            :_begin_script,
                :subscript,
                :superscript,
            :_end_script,
            :timestamp,
            :table_cell,
            :_begin_markup,
                :bold,
                :italic,
                :underline,
                :verbatim,
                :code,
                :strikethrough,
            :_end_markup,
        :_end_objects,
        :plaintext,
    :_end_all,
)


# Kind construction

const KIND_MARKER_OFFSETS = let markers = [0 => 0]
    for (i, kind) in enumerate(KIND_NAMES)
        if startswith(String(kind), '_')
            push!(markers, i => length(markers))
        end
    end
    Tuple(markers)
end

const KIND_SPECIAL_SETS = let n2k(set) = mapreduce(n -> UInt64(1) << (kind_number(n) - 1), xor, set)
    markup = n2k((:bold, :italic, :underline, :verbatim, :code, :strikethrough))
    minimal_objs = markup | n2k((:plaintext, :entity, :latex_fragment, :superscript, :subscript))
    all_objs = let objmask = UInt64(0)
        kfirst = kind_number(:entity)
        klast = kind_number(:strikethrough)
        for k in kfirst:klast
            objmask |= UInt64(1) << (k - 1)
        end
        objmask
    end
    standard_objs = all_objs ⊻ n2k((:citation_reference, :table_cell))
    hashplus = n2k((:block, :dynamic_block, :comment_block, :example_block, :source_block, :verse_block, :keyword))
    (:minimal_objects => reinterpret(Kind, minimal_objs),
     :standard_objects => reinterpret(Kind, standard_objs),
     Symbol("#+") => reinterpret(Kind, hashplus))
end


# Construction and display

function Kind(number::Number)
    reinterpret(Kind, UInt64(1) << (number - 1))
end

function Kind(name::String, tag::UInt8; start::Bool = false, stop::Bool = false)
    kmod = UInt64(tag) << 56
    if start
        kmod |= KIND_BEGIN
    end
    if stop
        kmod |= KIND_END
    end
    kint = kind_number(Symbol(name))
    if isnothing(kint)
        isempty(name) && return reinterpret(Kind, kmod)
        sname = Symbol(name)
        for (kset, kind) in KIND_SPECIAL_SETS
            sname == kset && return kind
        end
        mbeg = kind_number(Symbol("_begin_$name"))
        mend = kind_number(Symbol("_end_$name"))
        if !isnothing(mbeg) && !isnothing(mend)
            kmask = UInt64(0)
            for i in (mbeg - 1):(mend - 2)
                kmask |= UInt64(1) << i
            end
            return reinterpret(Kind, kmod | kmask)
        end
        throw(ArgumentError("Unknown kind: $name"))
    end
    reinterpret(Kind, kmod | UInt64(1) << (kint - 1))
end

function Kind(name::String)
    tag = UInt8(0)
    start, stop = false, false
    if startswith(name, '<')
        start = true
        name = name[2:end]
    end
    if startswith(name, '>')
        stop = true
        name = name[2:end]
    end
    if endswith(name, ']') && count('[', name) == 1
        tagidx = findfirst('[', name)::Int
        tag = tryparse(UInt8, @view name[(tagidx + 1):(end - 1)])
        isnothing(tag) && throw(ArgumentError("Invalid tag number: $name"))
        name = name[1:(tagidx - 1)]
    end
    Kind(name, tag; start, stop)
end

Kind(name::Symbol) = Kind(String(name))

# const KIND_NAMED_SETS = let sets = Pair{Symbol, Kind}[]
#     for name in KIND_NAMES
#         if startswith(String(name), "_begin_")
#             setname = Symbol(replace(String(name), "_begin_" => ""))
#             push!(sets, setname => Kind(setname))
#         end
#     end
#     Tuple(sets)
# end

function Base.show(io::IO, k::Kind)
    ku = reinterpret(UInt64, k)
    ks = Int[]
    for i in 1:54
        ku & (UInt64(1) << (i - 1)) != 0 && push!(ks, i)
    end
    for (i, _) in KIND_MARKER_OFFSETS
        i == 0 && continue
        for (ki, k) in enumerate(ks)
            if i <= k
                ks[ki] += 1
            end
        end
    end
    knames = [KIND_NAMES[k] for k in ks]
    if !Base.isvisible(Symbol("@K_str"), @__MODULE__, get(io, :module, Main))
        print(io, @__MODULE__, '.')
    end
    print(io, "K\"")
    if ku & KIND_BEGIN != 0
        print(io, '<')
    end
    if ku & KIND_END != 0
        print(io, '>')
    end
    join(io, knames, '|')
    if tag(k) != 0
        print(io, '[', tag(k), ']')
    end
    print(io, '"')
end

const KINDS = let kinds = Kind[]
    for kname in KIND_NAMES
        startswith(String(kname), '_') && continue
        push!(kinds, Kind(kname))
    end
    Tuple(kinds)
end

"""
    K"names..." -> Kind

Create a `Kind` for all of `names`, optionally with flags and a tag.

Names should be separated by `|`. The beginning and end flags are
supported by prefixing `<` and `>`, respectively. A tag can be added
by suffixing the names with `[tag]`. The tag must be a number between
0 and 255, and defaults to 0 if not explicitly set.

# Examples

- `K"block|drawer"`
- `K"<block"`
- `K"block[1]"`
- `K">block[27]"`
"""
macro K_str(name::String)
    mapreduce(Kind ∘ String, |, split(name, '|'))
end


# Kind restrictions

const ELEMENT_RESTRICTIONS = (
    K"paragraph|verse_block" => K"standard_objects",
    K"table_row" => K"table_cell",
    K"clock|planning" => K"timestamp",
    K"lesser_elements" => K"plaintext",
    K"property_drawer" => K"node_property",
    K"table" => K"table_row",
    K"list" => K"item",
    K"greater_elements" => K"greater_elements|lesser_elements" ⊻ K"planning|property_drawer|table_row|item|node_property",
)

const OBJECT_RESTRICTIONS = (
    K"verbatim" => K"verbatim",
    K"code" => K"code",
    K"script|markup|citation_reference|footnote_reference|radio_target" => K"standard_objects",
    K"citation" => K"citation_reference",
    K"regular_link" => K"minimal_objects" | K"export_snippet|inline_call|source_block|macro|statistics_cookie",
    K"table_cell" => K"minimal_objects" | K"citation|export_snippet|footnote_reference|link|macro|radio_target|target|timestamp",
)

const SECONDARY_RESTRICTIONS = (
    K"heading|item" => K"standard_objects" ⊻ K"linebreak",
    K"keyword" => K"standard_objects" ⊻ K"footnote_reference",
)

function all_restrictions(k::Kind)
    involved, implicit, reslist = if k & K"objects" != K""
        K"objects", K"elements", OBJECT_RESTRICTIONS
    else
        K"all", K"", ELEMENT_RESTRICTIONS
    end
    allowed = k | involved
    for (rk, res) in reslist
        if !isempty(k & rk)
            allowed &= (res | implicit)
            k = k & !rk
        end
        (k & involved) == K"" && break
    end
    allowed
end

const FLAT_RESTRICTIONS = let res = Kind[]
    for kind in K"all"
        push!(res, all_restrictions(kind) ⊻ kind)
    end
    Tuple(res)
end

function restrictions(k::Kind)
    if k == K""
        K"elements"
    elseif length(k) == 1
        FLAT_RESTRICTIONS[kind_number(k)]
    else
        all_restrictions(k)
    end
end
