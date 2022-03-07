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

mutable struct Clock{T <: Union{TimestampInactive, TimestampInactiveRange}} <: LesserElement
    timestamp::T
    duration::Union{Nothing, Tuple{Integer, Integer}}
end

mutable struct DiarySexp <: LesserElement
    sexp::AbstractString
end

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

mutable struct Keyword{V <: Union{<:AbstractString, Vector{Object}, Nothing}} <: LesserElement
    key::AbstractString
    value::V
end

mutable struct AffiliatedKeyword{V <: Union{<:AbstractString, Vector{Object}, Nothing}} <: LesserElement
    key::AbstractString
    optval::Union{<:AbstractString, Vector{Object}, Nothing}
    value::V
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
