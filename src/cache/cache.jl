# Make modification to the content clear the cache
function Base.setproperty!(o::Org, name::Symbol, value)
    if name == :contents
        o.cache = OrgCache(o)
    end
    setfield!(o, name, value)
end

function Base.getproperty(c::OrgCache, name::Symbol)
    if isnothing(getfield(c, name))
        setfield!(c, name, gencache(c, Val(name)))
    end
    getfield(c, name)
end

function gencache(c::OrgCache, ::Val{:elements})
    Vector{Union{Heading, Section, OrgGreaterElement, OrgElement}}(
        OrgElementIterator(c.doc) |> collect)
end

function gencache(c::OrgCache, ::Val{:components})
    Vector{OrgComponent}(OrgIterator(c.doc) |> collect)
end

function gencache(c::OrgCache, ::Val{:headings})
    Vector{Heading}(filter(h -> h isa Heading, c.elements))
end

function gencache(c::OrgCache, ::Val{:footnotes})
    footnotes = Dict{Union{AbstractString, FootnoteRef}, Tuple{Int, Union{FootnoteRef, FootnoteDef}}}()
    i = 1
    for f in filter(f -> f isa FootnoteDef || f isa FootnoteRef, c.components)
        if !isnothing(f.definition)
            footnotes[something(f.label, f)] = (i, f)
            i += 1
        end
    end
    footnotes
end
