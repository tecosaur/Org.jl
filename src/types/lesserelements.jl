abstract type OrgLesserElement <: OrgElement end

mutable struct BabelCall <: OrgLesserElement
    name::AbstractString
end

abstract type Block <: OrgLesserElement end

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
    contents::Vector{OrgLesserElement}
end
mutable struct CustomBlock <: Block
    name::AbstractString
    data::Union{AbstractString, Nothing}
    contents::Vector{AbstractString}
end

mutable struct Clock <: OrgLesserElement end

mutable struct DiarySexp <: OrgLesserElement end

mutable struct Planning <: OrgLesserElement
    deadline::Union{Timestamp, Nothing}
    scheduled::Union{Timestamp, Nothing}
    closed::Union{Timestamp, Nothing}
end

mutable struct Comment{S <: AbstractString} <: OrgLesserElement
    contents::Vector{S}
end

mutable struct FixedWidth{S <: AbstractString} <: OrgLesserElement
    contents::Vector{S}
end

struct HorizontalRule <: OrgLesserElement end

mutable struct Keyword <: OrgLesserElement
    key::AbstractString
    value::AbstractString
end

mutable struct LaTeXEnvironment <: OrgLesserElement
    name::AbstractString
    contents::Vector{AbstractString}
end

mutable struct NodeProperty <: OrgLesserElement
    name::AbstractString
    additive::Bool
    value::AbstractString
end

mutable struct Paragraph <: OrgLesserElement
    contents::Vector{OrgObject}
end

mutable struct TableRow <: OrgLesserElement
    cells::Vector{TableCell}
end
struct TableHrule <: OrgLesserElement end
