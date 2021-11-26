abstract type OrgElement <: OrgComponent end # Org Syntax §4
include("objects.jl") # Org Syntax §5

mutable struct BabelCall <: OrgElement # Org Syntax §4.1
    name::AbstractString
end

abstract type Block <: OrgElement end

mutable struct CommentBlock <: Block
    contents::AbstractString
end
mutable struct ExampleBlock <: Block
    contents::AbstractString
end
mutable struct SourceBlock <: Block
    lang::Union{AbstractString, Nothing}
    arguments::Union{AbstractString, Nothing}
    contents::AbstractString
end
mutable struct VerseBlock <: Block
    contents::Vector{OrgElement}
end
mutable struct CustomBlock <: Block
    name::AbstractString
    data::Union{AbstractString, Nothing}
    contents::AbstractString
end

mutable struct DiarySexp <: OrgElement end # Org Syntax §4.3

mutable struct Planning <: OrgElement end # Org Syntax §4.3

mutable struct Comment <: OrgElement
    contents::AbstractString
end

mutable struct FixedWidth <: OrgElement
    contents::AbstractString
end

struct HorizontalRule <: OrgElement end

mutable struct Keyword <: OrgElement
    key::AbstractString
    value::AbstractString
end

mutable struct LaTeXEnvironment <: OrgElement
    name::AbstractString
    contents::AbstractString
end

mutable struct NodeProperty <: OrgElement
    name::AbstractString
    additive::Bool
    value::AbstractString
end

mutable struct Paragraph <: OrgElement
    objects::Vector{OrgObject}
end

mutable struct TableRow <: OrgElement
    cells::Vector{TableCell}
end
struct TableHrule <: OrgElement end

struct EmptyLine <: OrgElement end
