abstract type LesserElement <: Element end

mutable struct BabelCall <: LesserElement
    name::SubString{String}
end

abstract type Block <: LesserElement end

mutable struct CommentBlock <: Block
    contents::Vector{SubString{String}}
end
mutable struct ExampleBlock <: Block
    contents::Vector{SubString{String}}
end
mutable struct ExportBlock <: Block
    backend::SubString{String}
    contents::Vector{SubString{String}}
end
mutable struct SourceBlock <: Block
    lang::Union{SubString{String}, Nothing}
    arguments::Union{SubString{String}, Nothing}
    contents::Vector{SubString{String}}
end
mutable struct VerseBlock <: Block
    contents::Vector{LesserElement}
end

mutable struct Clock{T <: Union{TimestampInactive, TimestampInactiveRange}} <: LesserElement
    timestamp::T
    duration::Union{Nothing, Tuple{Integer, Integer}}
end

mutable struct DiarySexp <: LesserElement
    sexp::SubString{String}
end

mutable struct Planning <: LesserElement
    deadline::Union{Timestamp, Nothing}
    scheduled::Union{Timestamp, Nothing}
    closed::Union{Timestamp, Nothing}
end

mutable struct Comment <: LesserElement
    contents::Vector{SubString{String}}
end

mutable struct FixedWidth <: LesserElement
    contents::Vector{SubString{String}}
end

struct HorizontalRule <: LesserElement end

mutable struct Keyword{V <: Union{SubString{String}, Vector{Object}, Nothing}} <: LesserElement
    key::SubString{String}
    value::V
end

mutable struct AffiliatedKeyword{V <: Union{SubString{String}, Vector{Object}, Nothing}} <: LesserElement
    key::SubString{String}
    optval::Union{SubString{String}, Vector{Object}, Nothing}
    value::V
end

mutable struct LaTeXEnvironment <: LesserElement
    name::SubString{String}
    contents::Vector{SubString{String}}
end

mutable struct NodeProperty <: LesserElement
    name::SubString{String}
    additive::Bool
    value::SubString{String}
end

mutable struct Paragraph <: LesserElement
    contents::Vector{Object}
end

mutable struct TableRow <: LesserElement
    cells::Vector{TableCell}
end
struct TableHrule <: LesserElement end
