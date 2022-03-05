mutable struct Section <: Element
    contents::Vector{Element}
    planning::Union{Planning, Nothing}
    properties::Union{PropertyDrawer, Nothing}
end

mutable struct Heading <: Element
    level::Integer
    keyword::Union{AbstractString, Nothing}
    priority::Union{AbstractString, Nothing}
    title::Vector{Object}
    tags::Vector{AbstractString}
    section::Union{Section, Nothing}
end
