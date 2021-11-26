abstract type OrgComponent end

mutable struct Org <: Any
    content::Vector{OrgComponent}
end
Org() = Org([])

include("sections.jl")
