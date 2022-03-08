mutable struct Section <: Element
    contents::Vector{Element}
    planning::Union{Planning, Nothing}
    properties::Union{PropertyDrawer, Nothing}
end

mutable struct Heading <: Element
    level::Integer
    keyword::Union{SubString{String}, Nothing}
    priority::Union{SubString{String}, Nothing}
    title::Vector{Object}
    tags::Vector{SubString{String}}
    section::Union{Section, Nothing}
end
