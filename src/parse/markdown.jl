using Markdown

import Base.convert

function convert(::Type{OrgDoc}, md::Markdown.MD)
    elements = map(convert.(Component, md.content)) do e
        if e isa Element
            (e,)
        elseif e isa Vector
            e
        end
    end |> Iterators.flatten |> collect
    heading_positions = findall(e -> e isa Heading, elements)
    if length(heading_positions) == 0
        OrgDoc([Section(elements, nothing, nothing)])
    else
        sectioning = Union{Heading, Section}[]
        if heading_positions[1] > 1
            push!(sectioning, Section(elements[1:heading_positions[1]-1], nothing, nothing))
        end
        for (hpos, hend) in zip(heading_positions, vcat(heading_positions[2:end], length(elements)))
            if hend < length(elements)
                hend -= 1
            end
            if hpos < hend
                elements[hpos].section = Section(elements[hpos+1:hend], nothing, nothing)
            end
            push!(sectioning, elements[hpos])
        end
        OrgDoc(sectioning)
    end
end

convert(::Type{Component}, md::Markdown.MD) = convert(OrgDoc, md).contents

convert(::Type{Component}, h::Markdown.Header{level}) where {level} =
    Heading(level, nothing, nothing, convert.(Component, h.text), SubString{String}[], nothing)

convert(::Type{Component}, ::Markdown.HorizontalRule) = HorizontalRule()

convert(::Type{Component}, ::Markdown.LineBreak) = LineBreak()

convert(::Type{Component}, s::String) = TextPlain(s)

convert_mdmarkup(type::Symbol, text::String) =
    TextMarkup(type, SubString(text))

convert_mdmarkup(type::Symbol, text::Vector) =
    TextMarkup(type, convert.(Component, text))

convert(::Type{Component}, b::Markdown.Bold) =
    convert_mdmarkup(:bold, b.text)

convert(::Type{Component}, i::Markdown.Italic) =
    convert_mdmarkup(:bold, i.text)

function convert(::Type{Component}, code::Markdown.Code; inline::Bool=false)
    if inline
        convert_mdmarkup(:code, code.code)
    else
        SourceBlock(if code.language == ""
                        "julia" # assume Julia if unspecified
                    else code.language end,
                    nothing, split(code.code, '\n'))
    end
end

function convert(::Type{Component}, l::Markdown.Link)
    path = if occursin("://", l.url)
        LinkPath(split(l.url, r":(?://)", limit=2)...)
    else
        LinkPath(:fuzzy, SubString(l.url))
    end
    RegularLink(path, convert(Component, Markdown.Paragraph(l.text)).contents)
end

convert(::Type{Component}, l::Markdown.LaTeX) =
    LaTeXFragment(SubString(l.formula), (SubString("\\("), SubString("\\)")))

convert(::Type{Component}, f::Markdown.Footnote) =
    if isnothing(f.text)
        FootnoteReference(SubString(f.id), nothing)
    else
        FootnoteDefinition(SubString(f.id), convert.(f.text))
    end

convert(::Type{Component}, img::Markdown.Image) =
    RegularLink(LinkPath(split(img.url, "://", limit=2)...), nothing)

function convert(::Type{Component}, par::Markdown.Paragraph)
    Paragraph(
        map(par.content) do elt
            if elt isa Markdown.Code
                convert(Component, elt, inline=true)
            else
                convert(Component, elt)
            end
        end |> Vector{Object})
end

convert(::Type{Component}, a::Markdown.Admonition) =
    SpecialBlock(a.category, nothing, convert.(Component, a.content))

function convert(::Type{Component}, l::Markdown.List)
    olist, bullets = if Markdown.isordered(l)
        OrderedList, string.(1:length(l.items), '.')
    else
        UnorderedList, fill("-", length(l.items))
    end
    items = map(zip(bullets, l.items)) do (bullet, contents)
        Item(bullet, convert.(Component, contents))
    end
    olist(items)
end

# Might as well, just in case

convert(::Type{OrgDoc},
        md::Union{Markdown.HorizontalRule, Markdown.LineBreak,
                  Markdown.Bold, Markdown.Italic, Markdown.Code, Markdown.Link,
                  Markdown.LaTeX, Markdown.Footnote, Markdown.Image,
                  Markdown.Paragraph, Markdown.Admonition}) =
                      OrgDoc([Section([convert(Component, md)], nothing, nothing)])

convert(::Type{OrgDoc}, h::Markdown.Header) =
    OrgDoc([convert(Component, h)])
