include("greaterelements.jl") # Org Syntax §3

mutable struct Section <: OrgComponent # Org Syntax §1
    contents::Vector{Union{OrgGreaterElement, OrgElement}}
end

mutable struct Heading <: OrgComponent
    level::Integer
    keyword::Union{AbstractString, Nothing}
    priority::Union{AbstractString, Nothing}
    title::Vector{OrgObject}
    tags::Vector{AbstractString}
    section::Union{Section, Nothing}
    planning::Union{Planning, Nothing}
    properties::Union{PropertyDrawer, Nothing}
end
