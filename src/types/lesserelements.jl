abstract type LesserElement <: Element end

mutable struct BabelCall <: LesserElement
    name::AbstractString
end

abstract type Block <: LesserElement end

mutable struct CommentBlock <: Block
    contents::Vector{AbstractString}
end
mutable struct ExampleBlock <: Block
    contents::Vector{AbstractString}
end
mutable struct ExportBlock <: Block
    backend::AbstractString
    contents::Vector{AbstractString}
end
mutable struct SourceBlock <: Block
    lang::Union{AbstractString, Nothing}
    arguments::Union{AbstractString, Nothing}
    contents::Vector{AbstractString}
end
mutable struct VerseBlock <: Block
    contents::Vector{LesserElement}
end
mutable struct CustomBlock <: Block
    name::AbstractString
    data::Union{AbstractString, Nothing}
    contents::Vector{AbstractString}
end

mutable struct Clock <: LesserElement end

mutable struct DiarySexp <: LesserElement end

mutable struct Planning <: LesserElement
    deadline::Union{Timestamp, Nothing}
    scheduled::Union{Timestamp, Nothing}
    closed::Union{Timestamp, Nothing}
end

mutable struct Comment{S <: AbstractString} <: LesserElement
    contents::Vector{S}
end

mutable struct FixedWidth{S <: AbstractString} <: LesserElement
    contents::Vector{S}
end

struct HorizontalRule <: LesserElement end

mutable struct Keyword <: LesserElement
    key::AbstractString
    value::AbstractString
end

mutable struct LaTeXEnvironment <: LesserElement
    name::AbstractString
    contents::Vector{AbstractString}
end

mutable struct NodeProperty <: LesserElement
    name::AbstractString
    additive::Bool
    value::AbstractString
end

mutable struct Paragraph <: LesserElement
    contents::Vector{Object}
end

mutable struct TableRow <: LesserElement
    cells::Vector{TableCell}
end
struct TableHrule <: LesserElement end
