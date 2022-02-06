abstract type GreaterElement <: Element end

abstract type GreaterBlock <: GreaterElement end

mutable struct CenterBlock <: GreaterBlock
    parameters::Union{AbstractString, Nothing}
    contents::Vector{Element}
end
mutable struct QuoteBlock <: GreaterBlock
    parameters::Union{AbstractString, Nothing}
    contents::Vector{Element}
end
mutable struct SpecialBlock <: GreaterBlock
    name::AbstractString
    parameters::Union{AbstractString, Nothing}
    contents::Vector{Element}
end

mutable struct Drawer <: GreaterElement
    name::AbstractString
    contents::Vector{Element}
end

mutable struct DynamicBlock <: GreaterElement
    name::AbstractString
    parameters::Union{AbstractString, Nothing}
    contents::Vector{Element}
end

mutable struct FootnoteDefinition <: GreaterElement
    label::AbstractString
    definition::Vector{Element}
end

# See elements.jl for InlineTask for load order reasons

abstract type List <: GreaterElement end

mutable struct Item <: GreaterElement
    bullet::AbstractString
    counterset::Union{AbstractString, Nothing}
    checkbox::Union{Char, Nothing}
    tag::Union{Vector{OrgComponent}, Nothing}
    contents::Vector{OrgComponent}
end

mutable struct UnorderedList <: List
    items::Vector{Item}
end
mutable struct OrderedList <: List
    items::Vector{Item}
end
mutable struct DescriptiveList <: List
    items::Vector{Item}
end

mutable struct PropertyDrawer <: GreaterElement
    contents::Vector{NodeProperty}
end

mutable struct Table <: GreaterElement
    rows::Vector{Union{TableRow, TableHrule}}
    formulas::Vector{AbstractString}
end
