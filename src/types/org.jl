abstract type OrgComponent end

include("sections.jl")

include("cache.jl")

mutable struct Org
    settings::Dict
    contents::Vector{Union{Heading, Section}}
    cache::OrgCache
    function Org(settings::Dict, contents::Vector{<:Union{Heading, Section}})
        o = new(settings, contents, OrgCache())
        setfield!(o.cache, :doc, o)
        o
    end
end

Org(contents::Vector) = Org(Dict(), contents)
Org() = Org(Union{Heading, Section}[])
