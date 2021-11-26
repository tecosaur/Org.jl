abstract type OrgGreaterElement <: OrgComponent end # Org Syntax §3
include("elements.jl") # Org Syntax §4

mutable struct GreaterBlock <: OrgGreaterElement
end

mutable struct Drawer <: OrgGreaterElement
    name::AbstractString
    contents::Vector{OrgElement}
end

mutable struct DynamicBlock <: OrgGreaterElement
    name::AbstractString
    parameters::Union{AbstractString, Nothing}
    contents::Vector{OrgElement}
end

mutable struct FootnoteDef <: OrgGreaterElement
    label::AbstractString
    contents::Vector{OrgElement}
end

mutable struct InlineTask <: OrgGreaterElement
end

abstract type List <: OrgGreaterElement end

mutable struct Item <: OrgGreaterElement
    bullet::AbstractString
    counterset::Union{AbstractString, Nothing}
    checkbox::Union{Char, Nothing}
    tag::Union{AbstractString, Nothing}
    contents::Union{Vector{OrgObject}, Nothing}
    sublist::Union{List, Nothing}
end

mutable struct UnorderedList <: List
    items::Vector{Item}
end
mutable struct OrderedList <: List
    items::Vector{Item}
end

mutable struct PropertyDrawer <: OrgGreaterElement
    name::AbstractString
    contents::Vector{NodeProperty}
end

mutable struct Table <: OrgGreaterElement
    rows::Vector{Union{TableRow, TableHrule}}
    formulas::Vector{AbstractString}
end
