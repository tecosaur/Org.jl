parsetree(org::Org, maxdepth=-1) = parsetree(stdout, org, maxdepth)
parsetree(org::OrgComponent, maxdepth=-1) = parsetree(stdout, org, maxdepth)

function parsetree(io::IO, org::Org, maxdepth=-1, depth=0)
    printstyled(io, "Org Parse Tree", color=:yellow)
    if length(org.contents) == 0
        printstyled(io, " (empty)\n", color=:light_black)
    else
        print(io, '\n')
        parsetree.(Ref(io), org.contents, maxdepth, depth+1)
    end
    nothing
end

function printstructure(io::IO, component::AbstractString, description,
                        contents, maxdepth, depth, color=:yellow, bold=false)
    printstyled(io, ' '^4depth, component; bold, color)
    if !isnothing(description)
        printstyled(io, ' ', description, color=:green)
    end
    if isnothing(contents)
        print(io, '\n')
    elseif contents isa Vector && length(contents) == 0
        printstyled(io, " (empty)\n", color=:light_black)
    elseif ! (contents isa Vector{<:OrgComponent})
        print(io, '\n')
    elseif depth == maxdepth
        printstyled(io, " [hidden]\n", color=:light_black)
    else
        print(io, '\n')
    end
    if !isnothing(contents)
        parsetree.(Ref(io), contents, maxdepth, depth+1)
    end
    nothing
end

parsetree(io::IO, h::Heading, maxdepth::Integer, depth::Integer) =
    printstructure(io, "Heading", '(' * string(Paragraph(h.title)) * ')',
                   filter(!isnothing, [h.planning, h.properties, h.section]),
                   maxdepth, depth, :yellow, true)

parsetree(io::IO, s::Section, maxdepth::Integer, depth::Integer) =
    printstructure(io, "Section", nothing, s.contents, maxdepth, depth, :yellow, true)

parsetree(io::IO, l::L, maxdepth::Integer, depth::Integer) where {L <: List} =
    printstructure(io, string(L), l.items[1].bullet, l.items, maxdepth, depth, :magenta, true)

function parsetree(io::IO, component::T, maxdepth::Integer, depth::Integer=0) where {T <: OrgComponent}
    contents = if applicable(iterate, component)
        collect(component)
    end
    bold, color = if T <: GreaterElement
        (false, :magenta)
    elseif T <: Element
        (false, :blue)
    else
        (false, :default)
    end
    printstructure(io, structurename(component), structuredesc(component),
                   contents, maxdepth, depth, color, bold)
end

structurename(::C) where {C<:OrgComponent} = string(nameof(C))
structuredesc(_::OrgComponent) = nothing

structuredesc(d::Drawer) = d.name
structuredesc(k::CitationReference) = string('@', k.key)
structuredesc(c::Citation) =
    string(something(c.style[1], "⋅"), " ", something(c.style[2], "⋅"))
structuredesc(f::FootnoteDefinition) = f.label
structuredesc(f::FootnoteReference) = something(f.label, "")
structuredesc(n::NodeProperty) = string(n.name, if n.additive "+" else "" end)
structuredesc(s::SourceBlock) = s.lang
structuredesc(l::Link) = l.path.protocol
structuredesc(m::Macro) = m.name
structurename(t::TextMarkup) = "Text" * uppercasefirst(string(t.formatting))
structuredesc(t::TextMarkup{<:AbstractString}) =
    string(structuredesc(TextPlain(t.contents)))
structuredesc(t::TextPlain) = if length(t.text) <= 40
    sprint(show, t.text)
else
    string(sprint(show, t.text[1:20])[1:end-1], " … ",
           sprint(show, t.text[end-20:end])[2:end])
end
