function Base.:(==)(a::T, b::T) where {T <: OrgComponent}
    for f in fieldnames(T)
        if getproperty(a, f) != getproperty(b, f)
            return false
        end
    end
    true
end

import Base.:(*)

*(a::Org) = a
*(a::Org, b::Org) = Org([a.content; b.content])
*(orgs::Org...) = Org(getproperty.(orgs, :content) |> Iterators.flatten |> collect)
*(components::OrgComponent...) = Org(components)

# Section

*(a::Heading, b::Heading) = Org([Section(a, []), Section(b, [])])
*(h::Heading, o::OrgComponent) = Section(h, [o])
*(a::Section, b::Section) = Org([a, b])
*(s::Section, h::Heading) = Org([s, Section(h, [])])
*(s::Section, o::OrgComponent) = Section(s, [s.content; o])

# Greater Element

# Element

*(a::Paragraph, b::Paragraph) = Paragraph([a.objects, b.objects])

*(a::Comment, b::Comment) = Comment(a.contents * "\n" * b.contents)
*(a::FixedWidth, b::FixedWidth) = Comment(a.contents * "\n" * b.contents)

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

length(c::OrgComponent) = 1
iterate(c::OrgComponent) = (c, nothing)
iterate(_::OrgComponent, ::Nothing) = nothing

# Section

length(s::Section) = 1 + length(s.content)

iterate(s::Section) = (s.heading, 1)
iterate(s::Section, index::Integer) =
    if index <= length(s.content)
        (s.content[index], index + 1)
    end

# Greater Element

# Element

length(p::Paragraph) = length(p.objects)

iterate(p::Paragraph) =
    if length(p.objects) > 0
        (p.objects[1], 2)
    end
iterate(p::Paragraph, index::Integer) =
    if index <= length(p.objects)
        (p.objects[index], index + 1)
    end

# Object

## utilities

# function filtermap(org::Org, types::Vector{DataType}=[OrgComponent], fn::Function=identity)
#     org |> Iterators.flatten |> Iterators.flatten |> collect |>
#         components -> filter(c -> any(T -> c isa T, types), components) |>
#         fn
# end
