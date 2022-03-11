using Markdown

import Base.convert

function convert(::Type{OrgDoc}, md::Markdown.MD)
    elements = map(convert.(OrgComponent, md.content)) do e
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
            if hpos < hend
                elements[hpos].section = Section(elements[hpos+1:hend], nothing, nothing)
            end
            push!(sectioning, elements[hpos])
        end
        OrgDoc(sectioning)
    end
end

convert(::Type{OrgComponent}, md::Markdown.MD) = convert(OrgDoc, md).contents

convert(::Type{OrgComponent}, h::Markdown.Header{level}) where {level} =
    Heading(level, nothing, nothing, convert.(OrgComponent, h.text), SubString{String}[], nothing)

convert(::Type{OrgComponent}, ::Markdown.HorizontalRule) = HorizontalRule()

convert(::Type{OrgComponent}, ::Markdown.LineBreak) = LineBreak()

convert(::Type{OrgComponent}, s::String) = TextPlain(s)

convert_mdmarkup(type::Symbol, text::String) =
    TextMarkup(type, SubString(text))

convert_mdmarkup(type::Symbol, text::Vector) =
    TextMarkup(type, convert.(OrgComponent, text))

convert(::Type{OrgComponent}, b::Markdown.Bold) =
    convert_mdmarkup(:bold, b.text)

convert(::Type{OrgComponent}, i::Markdown.Italic) =
    convert_mdmarkup(:bold, i.text)

function convert(::Type{OrgComponent}, code::Markdown.Code; inline::Bool=false)
    if inline
        convert_mdmarkup(:code, code.code)
    else
        SourceBlock(if code.language == ""
                        "julia" # assume Julia if unspecified
                    else code.language end,
                    nothing, split(code.code, '\n'))
    end
end

function convert(::Type{OrgComponent}, l::Markdown.Link)
    path = if occursin("://", l.url)
        LinkPath(split(l.url, r":(?://)", limit=2)...)
    else
        LinkPath(:fuzzy, SubString(l.url))
    end
    RegularLink(path, convert(OrgComponent, Markdown.Paragraph(l.text)).contents)
end

convert(::Type{OrgComponent}, l::Markdown.LaTeX) =
    LaTeXFragment(SubString(l.formula), (SubString("\\("), SubString("\\)")))

convert(::Type{OrgComponent}, f::Markdown.Footnote) =
    if isnothing(f.text)
        FootnoteReference(SubString(f.id), nothing)
    else
        FootnoteDefinition(SubString(f.id), convert.(f.text))
    end

convert(::Type{OrgComponent}, img::Markdown.Image) =
    RegularLink(LinkPath(split(img.url, "://", limit=2)...), nothing)

function convert(::Type{OrgComponent}, par::Markdown.Paragraph)
    Paragraph(
        map(par.content) do elt
            if elt isa Markdown.Code
                convert(OrgComponent, elt, inline=true)
            else
                convert(OrgComponent, elt)
            end
        end |> Vector{Object})
end

convert(::Type{OrgComponent}, a::Markdown.Admonition) =
    SpecialBlock(a.category, nothing, convert.(OrgComponent, a.content))

# Might as well, just in case

convert(::Type{OrgDoc},
        md::Union{Markdown.HorizontalRule, Markdown.LineBreak,
                  Markdown.Bold, Markdown.Italic, Markdown.Code, Markdown.Link,
                  Markdown.LaTeX, Markdown.Footnote, Markdown.Image,
                  Markdown.Paragraph, Markdown.Admonition}) =
                      OrgDoc([Section([convert(OrgComponent, md)], nothing, nothing)])

convert(::Type{OrgDoc}, h::Markdown.Header) =
    OrgDoc([convert(OrgComponent, h)])
