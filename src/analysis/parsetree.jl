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
    contents = if :contents in fieldnames(T) &&
        component.contents isa Vector{<:OrgComponent}
        component.contents
    end
    bold, color = if T <: OrgGreaterElement
        (false, :magenta)
    elseif T <: OrgElement
        (false, :blue)
    else
        (false, :default)
    end
    printstructure(io, structurename(component), structuredesc(component),
                   contents, maxdepth, depth, color, bold)
end

structurename(::C) where {C<:OrgComponent} = string(nameof(C))
structuredesc(_::OrgComponent) = nothing

structurename(t::TextMarkup) = "Text" * uppercasefirst(string(t.type))
structuredesc(t::TextMarkup) = string(t.marker)
