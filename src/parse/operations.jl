function Base.:(==)(a::T, b::T) where {T <: OrgComponent}
    for f in fieldnames(T)
        if getproperty(a, f) != getproperty(b, f)
            return false
        end
    end
    true
end

import Base: (*), (==)

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

*(e::EmptyLine...) = EmptyLine()

# Object

*(objects::OrgObject...) = Paragraph(objects)
*(cells::TableCell...) = TableRow(cells)

function *(a::TextPlain{SubString}, b::TextPlain{SubString})
    if a.text.string === b.text.string &&
        a.text.offset + a.text.ncodeunits == b.text.offset
        TextPlain(@inbounds SubString(a.text.string, 1 + a.text.offset,
                                      b.text.offset + b.text.ncodeunits))
    else
        TextPlain(a.text * b.text)
    end
end

*(a::TextPlain, b::TextPlain) = TextPlain(a.text * b.text)

## Equality of elements with different subtypes

==(a::Org, b::Org) = a.contents == b.contents
==(a::TextPlain, b::TextPlain) = a.text == b.text

## conversion

## iteration

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

length(r::TableRow) = length(r.cells)
iterate(r::TableRow) = if length(r) > 0 (r.cells[1], 2) end
iterate(r::TableRow, index::Integer) =
    if index <= length(r.cells)
        (r.cells[index], index + 1)
    end

# Element

length(p::Paragraph) = length(p.contents)
iterate(p::Paragraph) = if length(p) > 0 (p.contents[1], 2) end
iterate(p::Paragraph, index::Integer) =
    if index <= length(p.contents)
        (p.contents[index], index + 1)
    end

# Object

## utilities

function flatten(component::OrgComponent; keepself=false, recursive=false)
    if applicable(iterate, component)
        finaliser = if recursive
            cs -> map(c -> flatten(c; keepself, recursive), cs) |> Iterators.flatten |> collect
        else identity end
        children = component |> collect |> finaliser
        if keepself vcat(component, children) else children end
    else (component,) end
end

flatten(org::Org; keepself=false, recursive=false) = flatten.(org.contents; keepself, recursive) |> Iterators.flatten |> collect

function filtermap(org::Org, types::Vector{<:Type}=[OrgComponent], fn::Function=identity)
    flatten(org, keepself=true, recursive=true) |>
        components -> filter(c -> any(T -> c isa T, types), components) .|>
        fn
end
