abstract type LesserElement <: Element end

mutable struct BabelCall <: LesserElement
    name::SubString{String}
end
BabelCall(name::String) = BabelCall(SubString(name))

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
Keyword(key::String, value::Union{Vector{<:Object}, Nothing}=nothing) =
    Keyword(SubString(key), value)
Keyword(key::String, value::String) = Keyword(SubString(key), SubString(value))
Keyword((key, value)::Pair{String, <:Union{String, Vector{<:Object}, Nothing}}) =
    Keyword(key, value)

mutable struct AffiliatedKeyword{V <: Union{SubString{String}, Vector{Object}, Nothing}} <: LesserElement
    key::SubString{String}
    optval::Union{SubString{String}, Vector{Object}, Nothing}
    value::V
end
AffiliatedKeyword(key::AbstractString, value) =
    AffiliatedKeyword(SubString(key), nothing,
                      if value isa String; SubString(value) else value end)
AffiliatedKeyword((key, value)::Pair{<:AbstractString, <:Any}) =
    AffiliatedKeyword(key, value)

mutable struct LaTeXEnvironment <: LesserElement
    name::SubString{String}
    contents::Vector{SubString{String}}
end
LaTeXEnvironment(name::String, contents::Vector{String}) =
    LaTeXEnvironment(SubString(name), SubString.(contents))
LaTeXEnvironment(name::String, contents::String) =
    LaTeXEnvironment(SubString(name), split(contents, '\n'))

mutable struct NodeProperty <: LesserElement
    name::SubString{String}
    additive::Bool
    value::SubString{String}
end
NodeProperty(name::String, value::String, additive::Bool=false) =
    NodeProperty(SubString(name), additive, SubString(value))
NodeProperty((name, value)::Pair{String, String}, additive::Bool=false) =
    NodeProperty(name, value, additive)

mutable struct Paragraph <: LesserElement
    contents::Vector{Object}
end
Paragraph(obj::Object) = Paragraph(Object[obj])
Paragraph(text::String) = Paragraph(TextPlain(text))
Paragraph() = Paragraph(Object[])

mutable struct TableRow <: LesserElement
    cells::Vector{TableCell}
end
TableRow(cellvals::Vector=[]) =
    TableRow(TableCell.(Vector{Union{String, Vector{Object}}}(cellvals)))

struct TableHrule <: LesserElement end
