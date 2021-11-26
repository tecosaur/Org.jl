abstract type OrgElement <: OrgComponent end # Org Syntax §4
include("objects.jl") # Org Syntax §5

mutable struct BabelCall <: OrgElement # Org Syntax §4.1
    name::AbstractString
end

mutable struct Block <: OrgElement
    name::AbstractString
    data::Union{AbstractString, Nothing}
    contents::AbstractString
end
# TODO 1st class src block, convert Block to a abstract type and subtype it?

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
