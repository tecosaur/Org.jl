abstract type OrgComponent end

mutable struct Org <: Any
    content::Vector{OrgComponent}
end
Org() = Org([])

macro org_str(content::String)
    content # TODO
end

include("sections.jl")
