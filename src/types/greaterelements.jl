abstract type GreaterElement <: Element end

abstract type GreaterBlock <: GreaterElement end

mutable struct CenterBlock <: GreaterBlock
    parameters::Union{SubString{String}, Nothing}
    contents::Vector{Element}
end
CenterBlock(contents::Vector{Element}) =
    CenterBlock(nothing, contents)
mutable struct QuoteBlock <: GreaterBlock
    parameters::Union{SubString{String}, Nothing}
    contents::Vector{Element}
end
QuoteBlock(contents::Vector{Element}) =
    QuoteBlock(nothing, contents)
mutable struct SpecialBlock <: GreaterBlock
    name::SubString{String}
    parameters::Union{SubString{String}, Nothing}
    contents::Vector{Element}
end
SpecialBlock(name::String, contents::Vector{Element}) =
    SpecialBlock(SubString(name), nothing, contents)

mutable struct Drawer <: GreaterElement
    name::SubString{String}
    contents::Vector{Element}
end
Drawer(name::String, contents::Vector{Element}) =
    Drawer(SubString(name), contents)

mutable struct DynamicBlock <: GreaterElement
    name::SubString{String}
    parameters::Union{SubString{String}, Nothing}
    contents::Vector{Element}
end

mutable struct FootnoteDefinition <: GreaterElement
    label::SubString{String}
    definition::Vector{Element}
end
FootnoteDefinition(label::String, definition::Vector{Element}) =
    FootnoteDefinition(SubString(label), definition)
FootnoteDefinition(label::String, definition::String) =
    FootnoteDefinition(SubString(label), Paragraph(definition))
FootnoteDefinition((label, definition)::Pair{String, <:Union{Vector{Element}, String}}) =
    FootnoteDefinition(label, definition)

# See elements.jl for InlineTask for load order reasons

abstract type List <: GreaterElement end

mutable struct Item <: GreaterElement
    bullet::SubString{String}
    counterset::Union{SubString{String}, Nothing}
    checkbox::Union{Char, Nothing}
    tag::Union{Vector{Object}, Nothing}
    contents::Vector{Element}
end
Item(bullet::String, tag::Union{Vector{Component}, Nothing},
     contents::Vector{Component};
     counterset::Union{SubString{String}, Nothing}=nothing,
     checkbox::Union{Char, Nothing}=nothing) =
         Item(SubString(bullet), counterset, checkbox, tag, contents)
Item(bullet::String, contents::Vector{Component};
     counterset::Union{SubString{String}, Nothing}=nothing,
     checkbox::Union{Char, Nothing}=nothing) =
         Item(bullet, nothing, contents; counterset, checkbox)
Item(contents::Vector{Component};
     counterset::Union{SubString{String}, Nothing}=nothing,
     checkbox::Union{Char, Nothing}=nothing) =
         Item("+", nothing, contents; counterset, checkbox)
Item(contents::String;
     counterset::Union{SubString{String}, Nothing}=nothing,
     checkbox::Union{Char, Nothing}=nothing) =
         Item(Component[Paragraph(contents)]; counterset, checkbox)

mutable struct UnorderedList <: List
    items::Vector{Item}
end
mutable struct OrderedList <: List
    items::Vector{Item}
end
mutable struct DescriptiveList <: List
    items::Vector{Item}
end

UnorderedList(items::Vector{String}) =
    UnorderedList(Item.(items))
OrderedList(items::Vector{String}) =
    OrderedList(Item.(string.(1:length(items), '.'), items))
DescriptiveList(items::Vector{Pair{String, String}}) =
    DescriptiveList(map((tag, value)::Pair -> Item("+", tag, value), items))
DescriptiveList(items::Dict{String, String}) =
    DescriptiveList(sort(items |> collect, by=first))

mutable struct PropertyDrawer <: GreaterElement
    contents::Vector{NodeProperty}
end
PropertyDrawer(nodeprops::Vector{Pair{String, String}}) =
    PropertyDrawer(NodeProperty.(nodeprops))
PropertyDrawer(nodeprops::Dict{String, String}) =
    PropertyDrawer(sort(nodeprops |> collect, by=first))

mutable struct Table <: GreaterElement
    rows::Vector{Union{TableRow, TableHrule}}
    formulas::Vector{SubString{String}}
end
Table(rows::Vector=Union{TableRow, TableHrule}[]) =
    Table(Vector{Union{TableRow, TableHrule}}(rows), SubString{String}[])
