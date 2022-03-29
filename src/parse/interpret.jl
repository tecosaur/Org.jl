# Methods to interpret string representations of Components

struct ComponentParseError <: Exception
    element::Type
    msg::SubString{String}
end

function Base.showerror(io::IO, ex::ComponentParseError)
    print(io, "Org parse error")
    print(io, " for component $(ex.element):\n")
    print(io, ex.msg, '\n')
    Base.Experimental.show_error_hints(io, ex)
end

macro parseassert(elem, expr::Expr, msg)
    function matchp(e::Expr)
        if e.head == :call && e.args[1] isa Symbol && e.args[1]::Symbol == :match
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
            throw(ComponentParseError($(esc(elem)), $(esc(msg))))
        end
    end
end

include("config.jl")
include("matchers.jl")
include("operations.jl")
include("parser.jl")
include("consumers.jl")

import Base.parse

function parse(component::Type{<:Component}, content::SubString{String})
    result = consume(component, content)
    if isnothing(result)
        msg = string("│ ", join(split(content, '\n'), "\n│ "),
                     "\ndoes not start with any recognised form of $component.")
        throw(ComponentParseError(component, msg))
    else
        len, obj = result
        @parseassert(component, len == ncodeunits(content),
                     string("│ ", join(split(content, '\n'), "\n│ "),
                            "\nis not just a $component."))
        obj
    end
end

parse(component::Type{<:Component}, content::String) =
    parse(component, SubString(content))

# ---------------------
# Org
# ---------------------

include("postprocess.jl")

function parse(::Type{OrgDoc}, content::AbstractString)
    o = OrgDoc(parseorg(lstrip(content), [Heading, Section]) |> Vector{Union{Heading, Section}})
    postprocess!(o)
    o
end

# ---------------------
# Sections
# ---------------------

function Heading(components::Vector{Union{Nothing, SubString{String}}})
    stars::SubString{String}, keyword, priority, title::SubString{String}, tags, section = components
    level = length(stars)
    tagsvec = if isnothing(tags); String[] else split(tags[2:end-1], ':') end
    Heading(level, keyword, priority,
            parseobjects(Heading, title), tagsvec,
            if !isnothing(section) && isnothing(match(r"^[ \t\r\n]*$", section))
                parse(Section, section) end)
end

function Section(components::Vector{Union{Nothing, SubString{String}}})
    content = rstrip(components[1]::SubString{String})
    planning, properties = nothing, nothing
    plan = consume(Planning, content)
    if !isnothing(plan)
        content = @inbounds SubString(content.string,
                                      content.offset + plan[1],
                                      content.offset + lastindex(content))
        planning = plan[2]
    end
    props = consume(PropertyDrawer, content)
    if !isnothing(props)
        content = @inbounds SubString(content.string,
                                        content.offset + props[1] + 1,
                                        content.offset + lastindex(content))
        properties = props[2]
    end
    Section(parseorg(content, org_element_matchers, org_element_fallbacks) |> Vector{Element},
            planning, properties)
end

# ---------------------
# Greater Elements
# ---------------------

function GreaterBlock(components::Vector{Union{Nothing, SubString{String}}})
    name::SubString{String}, parameters, contents::SubString{String} = components
    name = ensurelowercase(name)
    containedelem = parseorg(contents, org_element_matchers, org_element_fallbacks)
    if name == "center"
        CenterBlock(parameters, containedelem)
    elseif name == "quote"
        QuoteBlock(parameters, containedelem)
    else
        SpecialBlock(name, parameters, containedelem)
    end
end

function Drawer(components::Vector{Union{Nothing, SubString{String}}})
    # When a draw by the same name is inside, it should be treated as a paragraph
    name::SubString{String}, content = components
    Drawer(name, if !isnothing(content)
               parse(Section, content).contents
           else
               Element[]
           end)
end

function DynamicBlock(components::Vector{Union{Nothing, SubString{String}}})
    name::SubString{String}, parameters, contents::SubString{String} = components
    containedelem = parseorg(contents, org_element_matchers, org_element_fallbacks)
    DynamicBlock(name, parameters, containedelem)
end

# FootnoteDefinition has a custom consumer

# InlineTask

# Item has a custom consumer
# List has a custom consumer

function PropertyDrawer(components::Vector{Union{Nothing, SubString{String}}})
    nodetext::SubString{String} = components[1]
    nodes = parseorg(nodetext, [NodeProperty])
    PropertyDrawer(Vector{NodeProperty}(nodes))
end

function Table(components::Vector{Union{Nothing, SubString{String}}})
    table::SubString{String}, tblfms = components
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
    BabelCall(components[1]::SubString{String})
end

function Block(components::Vector{Union{Nothing, SubString{String}}})
    name::SubString{String}, data, contents = components
    lines = if !isnothing(contents)
        split(contents, '\n')
    else
        SubString{String}[]
    end
    for i in 1:length(lines)
        if startswith(lines[i], ",*") || startswith(lines[i], ",#+")
            lines[i] = @inbounds SubString(lines[i].string, 2 + lines[i].offset,
                                           lines[i].offset + lastindex(lines[i]))
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
    elseif name == "export"
        ExportBlock(data, lines)
    elseif name == "example"
        ExampleBlock(lines)
    end
end

# Clock has a custom consumer

function DiarySexp(components::Vector{Union{Nothing, SubString{String}}})
    DiarySexp(components[1]::SubString{String})
end

# Planning has a custom consumer

function Comment(components::Vector{Union{Nothing, SubString{String}}})
    content::SubString{String} = components[1]
    lines = split(content, '\n') .|> l ->
        @inbounds SubString(l.string, 1 + l.offset + ncodeunits(match(r"^[ \t]*# ?", l).match),
                            l.offset + lastindex(l))
    Comment(lines)
end

function FixedWidth(components::Vector{Union{Nothing, SubString{String}}})
    content::SubString{String} = components[1]
    lines = split(content, '\n') .|> l ->
        @inbounds SubString(l.string, 1 + l.offset + ncodeunits(match(r"^[ \t]*: ?", l).match),
                            l.offset + lastindex(l))
    FixedWidth(lines)
end

HorizontalRule(_::Vector{Union{Nothing, SubString{String}}}) = HorizontalRule()

function Keyword(components::Vector{Union{Nothing, SubString{String}}})
    key::SubString{String}, value = components
    key = ensurelowercase(key)
    if haskey(org_keyword_translations, key)
        key = org_keyword_translations[key]
    end
    if key in org_parsed_keywords && !isnothing(value)
        value = parseobjects(Keyword, value)
    end
    Keyword(key, value)
end

function LaTeXEnvironment(components::Vector{Union{Nothing, SubString{String}}})
    indent::SubString{String}, name::SubString{String}, content::SubString{String} = components
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
    name::SubString{String}, additive, value::SubString{String} = components
    NodeProperty(name, !isnothing(additive), strip(value))
end

function Paragraph(components::Vector{Union{Nothing, SubString{String}}})
    Paragraph(parseobjects(Paragraph, components[1]::SubString{String}))
end

function TableRow(components::Vector{Union{Nothing, SubString{String}}})
    TableRow(split(strip(components[1]::SubString{String}, '|'), '|') .|> strip .|>
        c -> TableCell(parseobjects(TableCell, c)))
end

# ---------------------
# Objects
# ---------------------

# Entity has a custom consumer

function LaTeXFragment(components::Vector{Union{Nothing, SubString{String}}})
    command, delimitedform = components
    if isnothing(delimitedform)
        LaTeXFragment(command::SubString{String}, nothing)
    else
        LaTeXFragment(delimitedform[3:end-2],
                      (delimitedform[1:2], delimitedform[end-1:end]))
    end
end

function ExportSnippet(components::Vector{Union{Nothing, SubString{String}}})
    backend::SubString{String}, snippet::SubString{String} = components
    ExportSnippet(backend, snippet)
end

function FootnoteReference(components::Vector{Union{Nothing, SubString{String}}})
    label, definition = components
    FootnoteReference(label, definition)
end

function InlineBabelCall(components::Vector{Union{Nothing, SubString{String}}})
    name::SubString{String}, header1, arguments, header2 = components
    InlineBabelCall(name, if isnothing(header1) header2 else header1 end, arguments)
end

# InlineSourceBlock has a custom consumer

function LineBreak(::Vector{Union{Nothing, SubString{String}}})
    LineBreak()
end

function parse(::Type{LinkPath}, content::SubString{String}, verify::Bool=true)
    protocolmatch = match(r"^([^:#*<>()\[\]{}\s]+):(?://)?(.*)$", content)
    if isnothing(protocolmatch)
        verify && @parseassert(LinkPath, !occursin(r"\\[\[\]]", content),
                               "\"$content\" cannot contain unescapesquare brackets")
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
        verify && @parseassert(LinkPath, !occursin(r"\\[\[\]]", content),
                               "\"$content\" cannot contain unescaped square brackets")
        LinkPath(protocol, path)
    end
end

# RadioLink is handled in a post-processing step

function PlainLink(components::Vector{Union{Nothing, SubString{String}}})
    path::SubString{String} = components[1]
    PlainLink(parse(LinkPath, path))
end

function AngleLink(components::Vector{Union{Nothing, SubString{String}}})
    path::SubString{String} = components[1]
    AngleLink(parse(LinkPath, path))
end

# RegularLink has a custom consumer

function Macro(components::Vector{Union{Nothing, SubString{String}}})
    name::SubString{String}, arguments = components
    Macro(name, if isnothing(arguments) || length(arguments) == 0; []
          else split(arguments, r"(?<!\\), ?") end)
end

function RadioTarget(components::Vector{Union{Nothing, SubString{String}}})
    target::SubString{String} = components[1]
    @parseassert(RadioTarget, match(r"^[^<>\n]*$", target),
                 "\"$target\" cannot contain <, >, or \\n")
    @parseassert(RadioTarget, !match(r"^\s|\s$", target),
                 "\"$target\" cannot start or end with whitespace")
    RadioTarget(parseobjects(RadioTarget, target))
end

function Target(components::Vector{Union{Nothing, SubString{String}}})
    target::SubString{String} = components[1]
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
    char::SubString{String}, type::SubString{String}, script::SubString{String} = components
    if type == "^"
        Superscript(char[1], script)
    else
        Subscript(char[1], script)
    end
end

function TableCell(components::Vector{Union{Nothing, SubString{String}}})
    content::SubString{String} = components[1]
    @parseassert(TableCell, !occursin("|", content),
                 "\"$content\" cannot contain \"|\"")
    TableCell(parseobjects(TableCell, strip(content)))
end
