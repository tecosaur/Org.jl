mutable struct Section <: OrgElement
    contents::Vector{Union{OrgElement}}
end

mutable struct Heading <: OrgElement
    level::Integer
    keyword::Union{AbstractString, Nothing}
    priority::Union{AbstractString, Nothing}
    title::Vector{OrgObject}
    tags::Vector{AbstractString}
    section::Union{Section, Nothing}
    planning::Union{Planning, Nothing}
    properties::Union{PropertyDrawer, Nothing}
end
