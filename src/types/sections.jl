include("greaterelements.jl") # Org Syntax §3

mutable struct Section <: OrgComponent # Org Syntax §1
    content::Vector{Union{OrgGreaterElement, OrgElement}}
end

mutable struct Heading <: OrgComponent
    level::Integer
    keyword::Union{AbstractString, Nothing}
    priority::Union{AbstractString, Nothing}
    title::AbstractString
    tags::Vector{AbstractString}
    section::Union{Section, Nothing}
end
