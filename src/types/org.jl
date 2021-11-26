abstract type OrgComponent end

include("sections.jl")

mutable struct Org <: Any
    contents::Vector{Union{Heading, Section}}
end
Org() = Org([])
