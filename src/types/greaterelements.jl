abstract type OrgGreaterElement <: OrgElement end # Org Syntax §3

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

mutable struct FootnoteDefinition <: OrgGreaterElement
    label::AbstractString
    definition::Vector{OrgElement}
end

mutable struct InlineTask <: OrgGreaterElement
end

abstract type List <: OrgGreaterElement end

mutable struct Item <: OrgGreaterElement
    bullet::AbstractString
    counterset::Union{AbstractString, Nothing}
    checkbox::Union{Char, Nothing}
    tag::Union{AbstractString, Nothing}
    contents::Vector{OrgComponent}
end

mutable struct UnorderedList <: List
    items::Vector{Item}
end
mutable struct OrderedList <: List
    items::Vector{Item}
end

mutable struct PropertyDrawer <: OrgGreaterElement
    contents::Vector{NodeProperty}
end

mutable struct Table <: OrgGreaterElement
    rows::Vector{Union{TableRow, TableHrule}}
    formulas::Vector{AbstractString}
end
