abstract type Component end

include("objects.jl")
include("elements.jl")

include("cache.jl")

mutable struct OrgDoc
    settings::Dict{AbstractString, Any}
    contents::Vector{Union{Heading, Section}}
    cache::OrgCache
    function OrgDoc(settings::Dict, contents::Vector{<:Union{Heading, Section}})
        o = new(settings, contents, OrgCache())
        setfield!(o.cache, :doc, o)
        o
    end
end

OrgDoc(contents::Vector{<:Union{Heading, Section}}) =
    OrgDoc(Dict{AbstractString, Any}(), contents)
OrgDoc() = OrgDoc(Union{Heading, Section}[])
