import Base: (*), (==)

# ---------------------
# Concatenation
# ---------------------

*(a::OrgDoc) = a
function *(a::OrgDoc, b::OrgDoc)
    if length(a.contents) == 0 || length(b.contents) == 0
        OrgDoc(vcat(a.contents, b.contents))
    elseif a.contents[end] isa Heading && b.contents[1] isa Heading
        OrgDoc(vcat(a.contents, b.contents))
    else
        mergedsec = a.contents[end] * b.contents[1]
        OrgDoc(vcat(a.contents[1:end-1], mergedsec, b.contents[2:end]) |> Vector{Union{Org.Heading, Org.Section}})
    end
end

# Section

*(hs::Heading...) = OrgDoc(collect(hs))
function *(a::Section, b::Section)
    ac = deepcopy(a)
    bc = deepcopy(b)
    mergedprops = if !isnothing(a.properties) && !isnothing(b.properties)
        PropertyDrawer(vcat((a.properties::PropertyDrawer).contents,
                            (b.properties::PropertyDrawer).contents))
    elseif isnothing(b.properties)
        a.properties
    elseif isnothing(a.properties)
        b.properties
    end
    if length(a.contents) > 0 && length(b.contents) > 0 &&
       a.contents[end] isa Paragraph && b.contents[1] isa Paragraph
        ac.contents[end] *= b.contents[1]
        Section(vcat(ac.contents, bc.contents[2:end]), ac.planning, mergedprops)
    else
        Section(vcat(ac.contents, bc.contents), ac.planning, mergedprops)
    end
end
function *(s::Section, o::Component)
    sc = deepcopy(s)
    if o isa Object
        if sc.contents[end] isa Paragraph
            sc.contents[end].contents =
                vcat(sc.contents[end].contents, o)
        else
            sc.contents = vcat(sc.contents, Paragraph(o))
        end
    else
        sc.contents = vcat(sc.contents, o)
    end
    sc
end
function *(h::Heading, o::Component)
    hc = copy(h)
    if isnothing(hc.section)
        hc.section = Section(Element[], nothing, nothing) * o
    else
        hc.section = h.section * o
    end
    hc
end
function *(h::Heading, s::Section)
    hc = deepcopy(h)
    if !isnothing(hc.section)
        hc.section = hc.section::Section * s
    else
        hc.section = s
    end
    hc
end

# Greater Element

*(components::Vector{Element}...) =
    Section(components, nothing, nothing)

# Element

*(a::Paragraph, b::Paragraph) = Paragraph(vcat(a.contents, b.contents))

*(a::Comment, b::Comment) = Comment(vcat(a.contents, b.contents)::Vector{AbstractString})
*(a::FixedWidth, b::FixedWidth) = FixedWidth(vcat(a.contents, b.contents)::Vector{AbstractString})

*(rows::TableRow...) = Table(rows, [])

# Object

*(objects::Object...) = Paragraph(objects)
*(cells::TableCell...) = TableRow(cells)

function *(a::TextPlain{SubString{String}}, b::TextPlain{SubString{String}})
    if a.text.string === b.text.string &&
        a.text.offset + a.text.ncodeunits == b.text.offset
        TextPlain(@inbounds SubString(a.text.string, 1 + a.text.offset,
                                      b.text.offset + lastindex(b.text)))
    else
        TextPlain(a.text * b.text)
    end
end

*(a::TextPlain, b::TextPlain) = TextPlain(a.text * b.text)

# ---------------------
# Equality
# ---------------------

function ==(a::T, b::T) where {T <: Component}
    for f in fieldnames(T)
        F = fieldtype(T, f)
        if getproperty(a, f)::F != getproperty(b, f)::F
            return false
        end
    end
    true
end

==(a::OrgDoc, b::OrgDoc) = a.contents == b.contents
==(a::TextPlain, b::TextPlain) = a.text == b.text

## conversion

# ---------------------
# Terminality
# ---------------------

terminal(::Element) = false
terminal(::LesserElement) = true
terminal(::Planning) = false
terminal(::Clock) = false
terminal(::Paragraph) = false
terminal(::TableRow) = false

terminal(::Object) = true
terminal(::Citation) = false
terminal(::CitationReference) = false
# terminal(::Link) = false
# terminal(::RadioTarget) = false
terminal(::TableCell) = false
terminal(::TextMarkup{Vector{Object}}) = false

# ---------------------
# Iteration
# ---------------------

import Base: iterate, length

length(org::OrgDoc) = length(org.contents)
iterate(org::OrgDoc) =
    if length(org.contents) > 0
        (org.contents[1], 2)
    end
iterate(org::OrgDoc, index::Integer) =
    if index <= length(org.contents)
        (org.contents[index], index + 1)
    end

# Section

length(h::Heading) = length(h.title) + if isnothing(h.section) 0 else 1 end
iterate(h::Heading) = if length(h) > 0 (h.title[1], 2) end
iterate(h::Heading, index::Integer) =
    if index <= length(h.title)
        (h.title[index], index + 1)
    elseif index == 1 + length(h.title) && !isnothing(h.section)
        (h.section, index + 1)
    end

length(s::Section) =
     !isnothing(s.planning) + !isnothing(s.properties) + length(s.contents)
iterate(s::Section) = iterate(s, :planning)
iterate(s::Section, attr::Symbol) =
    if attr == :planning
        if !isnothing(s.planning)
            s.planning, :properties
        else
            iterate(s, :properties)
        end
    elseif attr == :properties
        if !isnothing(s.properties)
            s.properties, :contents
        else
            iterate(s, :contents)
        end
    else
        iterate(s, 1)
    end
iterate(s::Section, index::Integer) =
    if index <= length(s.contents)
        (s.contents[index], index + 1)
    end

length(p::Planning) = sum(map(!isnothing, [p.deadline, p.scheduled, p.closed]))
function iterate(p::Planning)
    times = filter(!isnothing, [p.deadline, p.scheduled, p.closed])
    times[1], times[2:end]
end
iterate(::Planning, rest::Vector) =
    if length(rest) > 0
        rest[1], rest[2:end]
    end

length(a::AffiliatedKeywordsWrapper) = 1 + length(a.keywords)
iterate(a::AffiliatedKeywordsWrapper) = (a.element, 1)
iterate(a::AffiliatedKeywordsWrapper, index::Integer) =
    if index <= length(a.keywords)
        (a.keywords[index], index + 1)
    end

# Greater Element

length(g::GreaterBlock) = length(g.contents)
iterate(g::GreaterBlock) = if length(g) > 0 (g.contents[1], 2) end
iterate(g::GreaterBlock, index::Integer) =
    if index <= length(g.contents)
        (g.contents[index], index + 1)
    end

length(d::Drawer) = length(d.contents)
iterate(d::Drawer) = if length(d) > 0 (d.contents[1], 2) end
iterate(d::Drawer, index::Integer) =
    if index <= length(d.contents)
        (d.contents[index], index + 1)
    end

length(d::DynamicBlock) = length(d.contents)
iterate(d::DynamicBlock) = if length(d) > 0 (d.contents[1], 2) end
iterate(d::DynamicBlock, index::Integer) =
    if index <= length(d.contents)
        (d.contents[index], index + 1)
    end

length(f::FootnoteDefinition) = length(f.definition)
iterate(f::FootnoteDefinition) =
    if length(f) > 0 (f.definition[1], 2) end
iterate(f::FootnoteDefinition, index::Integer) =
    if index <= length(f.definition)
        (f.definition[index], index + 1)
    end

length(l::List) = length(l.items)
iterate(l::List) = if length(l) > 0 (l.items[1], 2) end
iterate(l::List, index::Integer) =
    if index <= length(l.items)
        (l.items[index], index + 1)
    end

length(i::Item) = length(i.contents) + if isnothing(i.tag) 0 else length(i.tag::Vector) end
iterate(i::Item) = if length(i) > 0 iterate(i, 1) end
function iterate(i::Item, index::Integer)
    taglen = if isnothing(i.tag) 0 else length(i.tag::Vector) end
    if index <= taglen
        (i.tag[index], index + 1)
    elseif index - taglen <= length(i.contents)
        (i.contents[index - taglen], index + 1)
    end
end

length(p::PropertyDrawer) = length(p.contents)
iterate(p::PropertyDrawer) = if length(p) > 0 (p.contents[1], 2) end
iterate(p::PropertyDrawer, index::Integer) =
    if index <= length(p.contents)
        (p.contents[index], index + 1)
    end

length(t::Table) = length(t.rows)
iterate(t::Table) = if length(t) > 0 (t.rows[1], 2) end
iterate(t::Table, index::Integer) =
    if index <= length(t.rows)
        (t.rows[index], index + 1)
    end

# Lesser Element

length(c::Clock) = 1
iterate(c::Clock) = (c.timestamp, 0)
iterate(::Clock, ::Integer) = nothing

length(p::Paragraph) = length(p.contents)
iterate(p::Paragraph) = if length(p) > 0 (p.contents[1], 2) end
iterate(p::Paragraph, index::Integer) =
    if index <= length(p.contents)
        (p.contents[index], index + 1)
    end

length(r::TableRow) = length(r.cells)
iterate(r::TableRow) = if length(r) > 0 (r.cells[1], 2) end
iterate(r::TableRow, index::Integer) =
    if index <= length(r.cells)
        (r.cells[index], index + 1)
    end

# Object

length(k::CitationReference) =
    length(k.prefix) + length(k.suffix)
iterate(k::CitationReference) =
    if length(k.prefix) > 0
         (k.prefix[1], 2)
     elseif length(k.suffix) > 0
         (k.suffix[1], 2)
     end
iterate(k::CitationReference, index::Integer) =
    if index <= length(k.prefix)
        (k.prefix[index], index + 1)
    elseif index <= length(k.prefix) + length(k.suffix)
        (k.suffix[index-length(k.prefix)], index + 1)
    end

length(c::Citation) =
    length(c.globalprefix) + length(c.citerefs) + length(c.globalsuffix)
iterate(c::Citation) =
    (if length(c.globalprefix) > 0
         c.globalprefix[1]
     else
         c.citerefs[1]
     end, 2)
iterate(c::Citation, index::Integer) =
    if index <= length(c.globalprefix)
        (c.globalprefix[index], index + 1)
    elseif index <= length(c.globalprefix) + length(c.citerefs)
        (c.citerefs[index-length(c.globalprefix)], index + 1)
    elseif index <= length(c.globalprefix) + length(c.citerefs) + length(c.globalsuffix)
        (c.globalsuffix[index-length(c.globalprefix)-length(c.citerefs)], index + 1)
    end

length(f::FootnoteReference{<:Any, Vector{Object}}) = length(f.definition)
iterate(f::FootnoteReference{<:Any, Vector{Object}}) =
    if length(f) > 0 (f.definition[1], 2) end
iterate(f::FootnoteReference{<:Any, Vector{Object}}, index::Integer) =
    if index <= length(f.definition)
        (f.definition[index], index + 1)
    end

length(c::TableCell) = length(c.contents)
iterate(c::TableCell) = if length(c) > 0 (c.contents[1], 2) end
iterate(c::TableCell, index::Integer) =
    if index <= length(c.contents)
        (c.contents[index], index + 1)
    end

length(t::TextMarkup{Vector{Object}}) = length(t.contents)
iterate(t::TextMarkup{Vector{Object}}) =
    if length(t) > 0 (t.contents[1], 2) end
iterate(t::TextMarkup{Vector{Object}}, index::Integer) =
    if index <= length(t.contents)
        (t.contents[index], index + 1)
    end

# More iterating

struct OrgIterator
    o::OrgDoc
end

Base.IteratorSize(::OrgIterator) = Base.SizeUnknown()
iterate(it::OrgIterator) =
    if length(it.o.contents) > 0
        el, state = iterate(it.o)
        (el, Vector{Tuple}([(it.o, state), (el, nothing)]))
    end
iterate(it::OrgIterator, stack::Vector) =
    if length(stack) > 0
        next = if isnothing(stack[end][2])
            iterate(stack[end][1])
        else
            iterate(stack[end][1], stack[end][2])
        end
        if isnothing(next)
            pop!(stack)
            iterate(it, stack)
        else
            el, state = next
            stack[end] = (stack[end][1], state)
            if ! terminal(el)
                push!(stack, (el, nothing))
            end
            (el, stack)
        end
    end

struct OrgElementIterator
    o::OrgDoc
end

Base.IteratorSize(::OrgElementIterator) = Base.SizeUnknown()
iterate(it::OrgElementIterator) =
    if length(it.o.contents) > 0
        el, state = iterate(it.o)
        (el, Vector{Tuple}([(it.o, state), (el, nothing)]))
    end
iterate(it::OrgElementIterator, stack::Vector) =
    if length(stack) > 0
        next = if isnothing(stack[end][2])
            iterate(stack[end][1])
        else
            iterate(stack[end][1], stack[end][2])
        end
        if isnothing(next)
            pop!(stack)
            iterate(it, stack)
        elseif next[1] isa Object
            el, state = next
            stack[end] = (stack[end][1], state)
            iterate(it, stack)
        else
            el, state = next
            stack[end] = (stack[end][1], state)
            if ! terminal(el)
                push!(stack, (el, nothing))
            end
            (el, stack)
        end
    end

# ---------------------
# Accessors
# ---------------------

import Base.getindex

getindex(o::OrgDoc, i::Integer) = o.contents[i]

function getindex(props::PropertyDrawer, name::AbstractString)
    additive = if endswith(name, '+')
        name = name[1:end-1]
        true
    else
        false
    end
    matches = filter(n -> n.name == name && n.additive == additive, props.contents)
    if length(matches) == 1
        matches[1].value
    else
        nothing
    end
end

function getindex(h::Heading, prop::AbstractString)
    if isnothing(h.section) || isnothing(h.section.properties)
        nothing
    else
        getindex(h.section.properties, prop)
    end
end
