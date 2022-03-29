mutable struct Section <: Element
    contents::Vector{Element}
    planning::Union{Planning, Nothing}
    properties::Union{PropertyDrawer, Nothing}
end

Section(contents::Vector=Element[]) = Section(Vector{Element}(contents), nothing, nothing)

mutable struct Heading <: Element
    level::Integer
    keyword::Union{SubString{String}, Nothing}
    priority::Union{SubString{String}, Nothing}
    title::Vector{Object}
    tags::Vector{SubString{String}}
    section::Union{Section, Nothing}
end

Heading(level::Integer, title::Vector{Object}, section::Union{Section, Nothing}=nothing;
        keyword::Union{String, Nothing}=nothing,
        priority::Union{String, Nothing}=nothing,
        tags::Vector{String}=String[]) =
            Heading(level, if !isnothing(keyword) SubString(keyword) end,
                    if !isnothing(priority) SubString(priority) end,
                    title, SubString.(tags), section)

Heading(level::Integer, title::String, section::Union{Section, Nothing}=nothing;
        keyword::Union{String, Nothing}=nothing,
        priority::Union{String, Nothing}=nothing,
        tags::Vector{String}=String[]) =
            Heading(level, Object[TextPlain(title)], section; keyword, priority, tags)
