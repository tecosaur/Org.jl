abstract type OrgComponent end

include("objects.jl")
include("elements.jl")

include("cache.jl")

mutable struct OrgDoc
    settings::Dict
    contents::Vector{Union{Heading, Section}}
    cache::OrgCache
    function OrgDoc(settings::Dict, contents::Vector{<:Union{Heading, Section}})
        o = new(settings, contents, OrgCache())
        setfield!(o.cache, :doc, o)
        o
    end
end

OrgDoc(contents::Vector) = OrgDoc(Dict(), contents)
OrgDoc() = OrgDoc(Union{Heading, Section}[])
