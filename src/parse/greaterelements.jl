abstract type OrgGreaterElement <: OrgComponent end # Org Syntax §3
include("elements.jl") # Org Syntax §4

mutable struct GreaterBlock <: OrgGreaterElement # Org Syntax §3.1
end

mutable struct Drawer <: OrgGreaterElement # Org Syntax §3.2
    name::AbstractString
    contents
end
const DrawerRegex = r"^:([\w\-_]+):\n(.*?)\n:END:"

mutable struct DynamicBlock <: OrgGreaterElement # Org Syntax §3.3
    name::AbstractString
    parameters::Union{AbstractString, Nothing}
    contents
end

mutable struct FootnoteDef <: OrgGreaterElement # Org Syntax §3.4
    # [fn:LABEL] CONTENTS
    # contents can by anything but must stop before:
    # 1. another footnote def
    # 2. the next headline
    # 3. two consecutive empty lines
    label::AbstractString
    contents
end
const FootnoteDefRegex = r"^\[fn:([A-Za-z0-9-_]*)\] "

mutable struct InlineTask <: OrgGreaterElement # Org Syntax §3.5
end

mutable struct Item <: OrgGreaterElement # Org Syntax §3.6
    # BULLET COUNTERSET CHECKBOX TAG :: CONTENT
    bullet::AbstractString
    counterset::Union{AbstractString, Nothing}
    checkbox::Union{Char, Nothing}
    tag::Union{AbstractString, Nothing}
    content
end
const ItemRegex = r"^([*\-\+]|(?:[A-Za-z]|[0-9]+)[\.\)])(?:\s+\[\@([A-Za-z]|[0-9]+)\])?(?:\s+\[([ \-X])\])?(?:\s+([^\n]+)::)?\s+(.*)"
function Item(content::AbstractString)
    itemmatch = match(ItemRegex, content)
    @parseassert(Item, !inothing(itemmatch),
                 "\"$content\" did not match any recognised form")
    bullet, counterset, checkbox, tag, contents = itemmatch.captures
    Item(bullet, counterset, if !isnothing(checkbox) checkbox[1] end, tag, contents)
end

mutable struct List <: OrgGreaterElement # Org Syntax §3.6
    items::Vector{Item}
end

mutable struct PropertyDrawer <: OrgGreaterElement # Org Syntax §3.7
    name::AbstractString
    contents::Vector{NodeProperty}
end

mutable struct Table <: OrgGreaterElement # Org Syntax §3.8
    rows::Vector{Union{TableRow, TableHrule}}
    formulas::Vector{AbstractString}
end
const TableRegex = r"^([ \t]*\|[^\n]+(?:\n[ \t]*\|[^\n]+)*)((?:\n[ \t]*#\+TBLFM: [^\n]*)+)?"m
function Table(content::AbstractString)
    tablematch = match(TableRegex, content)
    table, tblfms = tablematch.captures
    rows = map(row -> if !isnothing(match(r"^[ \t]*\|[\-\+]+\|*$", row))
                   TableHrule() else TableRow(row) end,
               split(table, '\n'))
    # fill rows to same number of columns
    ncolumns = maximum(r -> if r isa TableRow length(r.cells) else 0 end, rows)
    for row in rows
        if row isa TableRow && length(row.cells) < ncolumns
            push!(row.cells, repeat([TableCell("")], ncolumns - length(row.cells))...)
        end
    end
    # formulas
    formulas = if isnothing(tblfms); [] else
        replace.(split(strip(tblfms), '\n'), r"\s*#\+TBLFM:\s*" => "")
    end
    Table(rows, formulas)
end
