import Base: (*), (==)

# ---------------------
# Concatenation
# ---------------------

*(a::Org) = a
*(a::Org, b::Org) = Org(vcat(a.contents, b.contents))
*(orgs::Org...) = Org(getproperty.(orgs, :content) |> Iterators.flatten |> collect)

# Section

*(hs::Heading...) = Org(hs)
*(a::Section, b::Section) = Section(vcat(a.contents, b.contents))
function *(s::Section, o::OrgComponent)
    sc = deepcopy(s)
    if o isa OrgObject
        if sc.section.contents[end] isa Paragraph
            sc.section.contents[end].contents =
                vcat(sc.section.contents[end].contents, o)
        else
            sc.section.contents = vcat(sc.section.contents, Paragraph(o))
        end
    else
        sc.section.contents = vcat(sc.section.contents, o)
    end
    sc
end
function *(h::Heading, o::OrgComponent)
    hc = copy(h)
    if isnothing(hc.section)
        hc.section = Section([]) * o
    else
        hc.section = h.section * o
    end
    hc
end
function *(h::Heading, s::Section)
    hc = copy(h)
    hc.section = vcat(hc.section.contents, s.contents)
    hc
end

# Greater Element

*(components::Vector{Union{OrgGreaterElement, OrgElement}}...) =
    Section([components])

# Element

*(a::Paragraph, b::Paragraph) = Paragraph([a.contents, b.contents])

*(a::Comment, b::Comment) = Comment(vcat(a.contents, b.contents))
*(a::FixedWidth, b::FixedWidth) = Comment(vcat(a.contents, b.contents))

*(rows::TableRow...) = Table(rows, [])

# Object

*(objects::OrgObject...) = Paragraph(objects)
*(cells::TableCell...) = TableRow(cells)

function *(a::TextPlain{SubString}, b::TextPlain{SubString})
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

function ==(a::T, b::T) where {T <: OrgComponent}
    for f in fieldnames(T)
        if getproperty(a, f) != getproperty(b, f)
            return false
        end
    end
    true
end

==(a::Org, b::Org) = a.contents == b.contents
==(a::TextPlain, b::TextPlain) = a.text == b.text

## conversion

# ---------------------
# Terminality
# ---------------------

terminal(::OrgElement) = false
terminal(::OrgLesserElement) = true
terminal(::Paragraph) = false
terminal(::TableRow) = false

terminal(::OrgObject) = true
terminal(::Citation) = false
terminal(::CitationReference) = false
# terminal(::Link) = false
# terminal(::RadioTarget) = false
terminal(::TableCell) = false
terminal(::TextMarkup{Vector{OrgObject}}) = false

# ---------------------
# Iteration
# ---------------------

import Base: iterate, length

length(org::Org) = length(org.contents)
iterate(org::Org) =
    if length(org.contents) > 0
        (org.contents[1], 2)
    end
iterate(org::Org, index::Integer) =
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

length(s::Section) = length(s.contents)
iterate(s::Section) = if length(s) > 0 (s.contents[1], 2) end
iterate(s::Section, index::Integer) =
    if index <= length(s.contents)
        (s.contents[index], index + 1)
    end

# Greater Element

length(d::Drawer) = length(d.contents)
iterate(d::Drawer) = if length(d) > 0 (d.contents[1], 2) end
iterate(d::Drawer, index::Integer) =
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

length(i::Item) = length(i.contents)
iterate(i::Item) = if length(i) > 0 (i.contents[1], 2) end
iterate(i::Item, index::Integer) =
    if index <= length(i.contents)
        (i.contents[index], index + 1)
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

length(f::FootnoteReference{<:Any, Vector{OrgObject}}) = length(f.definition)
iterate(f::FootnoteReference{<:Any, Vector{OrgObject}}) =
    if length(f) > 0 (f.definition[1], 2) end
iterate(f::FootnoteReference{<:Any, Vector{OrgObject}}, index::Integer) =
    if index <= length(f.definition)
        (f.definition[index], index + 1)
    end

length(c::TableCell) = length(c.contents)
iterate(c::TableCell) = if length(c) > 0 (c.contents[1], 2) end
iterate(c::TableCell, index::Integer) =
    if index <= length(c.contents)
        (c.contents[index], index + 1)
    end

length(t::TextMarkup{Vector{OrgObject}}) = length(t.contents)
iterate(t::TextMarkup{Vector{OrgObject}}) =
    if length(t) > 0 (t.contents[1], 2) end
iterate(t::TextMarkup{Vector{OrgObject}}, index::Integer) =
    if index <= length(t.contents)
        (t.contents[index], index + 1)
    end

# More iterating

struct OrgIterator
    o::Org
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
    o::Org
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
        if isnothing(next) || next[1] isa OrgObject
            pop!(stack)
            iterate(it, stack)
        else
            el, state = next
            stack[end] = (stack[end][1], state)
            if applicable(iterate, el)
                push!(stack, (el, nothing))
            end
            (el, stack)
        end
    end

# ---------------------
# Accessors
# ---------------------

import Base.getindex

getindex(o::Org, i::Integer) = o.contents[i]

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
    if isnothing(h.properties)
        nothing
    else
        getindex(h.properties, prop)
    end
end
