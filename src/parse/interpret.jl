# Methods to interpret string representations of OrgComponents

struct OrgComponentParseError <: Exception
    element::DataType
    msg::AbstractString
end

function Base.showerror(io::IO, ex::OrgComponentParseError)
    print(io, "Org parse error")
    print(io, " for component $(ex.element): ")
    print(io, ex.msg)
    Base.Experimental.show_error_hints(io, ex)
end

macro parseassert(elem, expr::Expr, msg)
    function matchp(e::Expr)
        if e.head == :call && e.args[1] == :match
            e = :(!(isnothing($e)))
        else
            e.args = map(matchp, e.args)
        end
        e
    end
    matchp(e::Any) = e
    expr = matchp(expr)
    quote
        if !($(esc(expr)))
            throw(OrgComponentParseError($(esc(elem)), $(esc(msg))))
        end
    end
end

include("parser.jl")

import Base.parse

function parse(component::Type{<:OrgComponent}, content::AbstractString)
    result = consume(component, content)
    if isnothing(result)
        throw(OrgComponentParseError(component, "\"$content\" does not start with any recognised form of $(component)"))
    else
        len, obj = result
        @parseassert(component, len == ncodeunits(content),
                     "\"$content\" is not just a $component")
        obj
    end
end

# ---------------------
# Org
# ---------------------

function parse(::Type{Org}, content::AbstractString)
    Org(Vector{Union{Heading, Section}}(parseorg(content, [Heading, Section])))
end

# ---------------------
# Sections
# ---------------------

function Heading(components::Vector{Union{Nothing, SubString{String}}})
    stars, keyword, priority, title, tags, section = components
    level = length(stars)
    tagsvec = if isnothing(tags); [] else split(tags[2:end-1], ':') end
    planning, properties = nothing, nothing
    if !isnothing(section)
        plan = consume(Planning, section)
        if !isnothing(plan)
            section = @inbounds SubString(section.string,
                                          section.offset + plan[1],
                                          section.offset + lastindex(section))
            planning = plan[2]
        end
        props = consume(PropertyDrawer, section)
        if !isnothing(props)
            section = @inbounds SubString(section.string,
                                          section.offset + props[1] + 1,
                                          section.offset + lastindex(section))
            properties = props[2]
        end
        if ncodeunits(section) == 0
            section = nothing
        end
    end
    Heading(level, keyword, priority,
            parseorg(title, OrgObjectMatchers, OrgObjectFallbacks), tagsvec,
            if !isnothing(section) && isnothing(match(r"^[ \t\r\n]*$", section))
                parse(Section, section) end,
            planning, properties)
end

function Section(components::Vector{Union{Nothing, SubString{String}}})
    content = rstrip(components[1])
    Section(parseorg(content, OrgElementMatchers, OrgElementFallbacks))
end

# ---------------------
# Greater Elements
# ---------------------

# Greater Block

function Drawer(components::Vector{Union{Nothing,SubString{String}}})
    name, content = components
    Drawer(name, if !isnothing(content)
               parse(Section, content).contents
           else
               OrgElement[]
           end)
end

# Dynamic Block
# FootnoteDefinition
# InlineTask

# Item has a custom consumer
# List has a custom consumer

function PropertyDrawer(components::Vector{Union{Nothing, SubString{String}}})
    nodetext = components[1]
    nodes = parseorg(nodetext, [NodeProperty])
    PropertyDrawer(Vector{NodeProperty}(nodes))
end

function Table(components::Vector{Union{Nothing, SubString{String}}})
    table, tblfms = components
    rows = map(row -> if !isnothing(match(r"^[ \t]*\|[\-\+]+\|*$", row))
                   TableHrule() else parse(TableRow, row) end,
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

# ---------------------
# Elements
# ---------------------

function BabelCall(components::Vector{Union{Nothing, SubString{String}}})
    BabelCall(components[1])
end

function Block(components::Vector{Union{Nothing, SubString{String}}})
    name, data, contents = components
    lines = if !isnothing(contents)
        split(contents, '\n')
    else
        String[]
    end
    for i in 1:length(lines)
        if startswith(lines[i], ",*")
            lines[i] = @inbounds SubString(lines[i].string, 2 + lines[i].offset,
                                           lines[i].offset + lines[i].ncodeunits)
        end
    end
    if name == "src"
        local lang, arguments
        if isnothing(data)
            lang, arguments = nothing, nothing
        else
            lang, arguments = match(r"^(\S+)( [^\n]+)?$", data).captures
        end
        SourceBlock(lang, arguments, lines)
    elseif name == "example"
        ExampleBlock(lines)
    else
        CustomBlock(name, data, lines)
    end
end

# Clock

# DiarySexp

# Planning has a custom consumer

function Comment(components::Vector{Union{Nothing, SubString{String}}})
    content = components[1]
    lines = split(content, '\n') .|> l ->
        @inbounds SubString(l.string, 1 + l.offset + ncodeunits(match(r"^[ \t]*# ?", l).match),
                            l.offset + l.ncodeunits)
    Comment(lines)
end

function FixedWidth(components::Vector{Union{Nothing, SubString{String}}})
    content = components[1]
    lines = split(content, '\n') .|> l ->
        @inbounds SubString(l.string, 1 + l.offset + ncodeunits(match(r"^[ \t]*: ?", l).match),
                            l.offset + l.ncodeunits)
    FixedWidth(lines)
end

HorizontalRule(_::Vector{Union{Nothing, SubString{String}}}) = HorizontalRule()

function Keyword(components::Vector{Union{Nothing, SubString{String}}})
    key, value = components
    Keyword(key, value)
end

function LaTeXEnvironment(components::Vector{Union{Nothing, SubString{String}}})
    indent, name, content = components
    lines = map(split(content, '\n')) do line
        if startswith(line, indent)
            @inbounds @view line[1+ncodeunits(indent):end]
        else
            line
        end
    end
    LaTeXEnvironment(name, lines)
end

function NodeProperty(components::Vector{Union{Nothing, SubString{String}}})
    name, additive, value = components
    NodeProperty(name, !isnothing(additive), strip(value))
end

function Paragraph(components::Vector{Union{Nothing, SubString{String}}})
    Paragraph(parseorg(components[1], OrgObjectMatchers, OrgObjectFallbacks))
end

function TableRow(components::Vector{Union{Nothing, SubString{String}}})
    TableRow(split(strip(components[1], '|'), '|') .|> strip .|>
        c -> TableCell(parseorg(c, OrgObjectMatchers, OrgObjectFallbacks)))
end

# ---------------------
# Objects
# ---------------------

# Entity has a custom consumer

function LaTeXFragment(components::Vector{Union{Nothing, SubString{String}}})
    command, delimitedform = components
    if isnothing(delimitedform)
        LaTeXFragment(command, nothing)
    else
        LaTeXFragment(delimitedform[3:end-2],
                      (delimitedform[1:2], delimitedform[end-2:end]))
    end
end

function ExportSnippet(components::Vector{Union{Nothing, SubString{String}}})
    backend, snippet = components
    ExportSnippet(backend, snippet)
end

function FootnoteReference(components::Vector{Union{Nothing, SubString{String}}})
    label, definition = components
    FootnoteReference(label, definition)
end

function InlineBabelCall(components::Vector{Union{Nothing, SubString{String}}})
    name, header1, arguments, header2 = components
    InlineBabelCall(name, if isnothing(header1) header2 else header1 end, arguments)
end

# InlineSourceBlock has a custom consumer

function LineBreak(::Vector{Union{Nothing, SubString{String}}})
    LineBreak()
end

function parse(::Type{LinkPath}, content::AbstractString, verify::Bool=true)
    protocolmatch = match(r"^([^#*\s:]+):(?://)?(.*)$", content)
    if isnothing(protocolmatch)
        verify && @parseassert(LinkPath, !occursin(r"\[|\]", content),
                               "\"$content\" cannot contain square brackets")
        if content[1] == '(' && content[end] == ')'
            LinkPath(:coderef, content[2:end-1])
        elseif content[1] == '#'
            LinkPath(:custom_id, content[2:end])
        elseif content[1] == '*'
            LinkPath(:heading, content[2:end])
        else
            LinkPath(:fuzzy, content)
        end
    else
        protocol, path = protocolmatch.captures
        verify && @parseassert(LinkPath, !occursin(r"\[|\]", path),
                               "path \"$path\" cannot contain square brackets")
        LinkPath(protocol, path)
    end
end

function Link(components::Vector{Union{Nothing, SubString{String}}})
    path, description = components
    Link(parse(LinkPath, path), description)
end

function Macro(components::Vector{Union{Nothing, SubString{String}}})
    name, arguments = components
    Macro(name, if isnothing(arguments) || length(arguments) == 0; []
          else split(arguments, r"(?<!\\), ?") end)
end

function RadioTarget(components::Vector{Union{Nothing, SubString{String}}})
    target = components[1]
    @parseassert(RadioTarget, match(r"^[^<>\n]*$", target),
                 "\"$target\" cannot contain <, >, or \\n")
    @parseassert(RadioTarget, !match(r"^\s|\s$", target),
                 "\"$target\" cannot start or end with whitespace")
    RadioTarget(parseorg(target, [TextPlain, TextMarkup, Entity, LaTeXFragment, Subscript, Superscript]))
end

function Target(components::Vector{Union{Nothing, SubString{String}}})
    target = components[1]
    @parseassert(Target, match(r"^[^<>\n]*$", target),
                 "\"$target\" cannot contain <, >, or \\n")
    @parseassert(Target, !match(r"^\s|\s$", target),
                 "\"$target\" cannot start or end with whitespace")
    Target(target)
end

function StatisticsCookie(components::Vector{Union{Nothing, SubString{String}}})
    percent, numerator, denominator = components
    if isnothing(percent)
        StatisticsCookieFraction(if !isnothing(numerator) parse(Int, numerator) end,
                                 if !isnothing(denominator) parse(Int, denominator) end)
    else
        StatisticsCookiePercent(percent)
    end
end

function Script(components::Vector{Union{Nothing, SubString{String}}})
    char, type, script = components
    if type == "^"
        Superscript(char[1], script)
    else
        Subscript(char[1], script)
    end
end

function TableCell(components::Vector{Union{Nothing, SubString{String}}})
    content = components[1]
    @parseassert(TableCell, !occursin("|", content),
                 "\"$content\" cannot contain \"|\"")
    TableCell(parseorg(strip(content), OrgObjectMatchers, OrgObjectFallbacks))
end
