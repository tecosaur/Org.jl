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

function parse(component::Type{<:OrgComponent}, content::AbstractString, verify::Bool=true)
    matcher = orgmatcher(component)
    if !verify
        return component(match(matcher, content).captures)
    end
    @parseassert(component, !isnothing(matcher),
                 "no matcher is defined for $component")
    if matcher isa Regex
        rxmatch = match(matcher, content)
        @parseassert(component, !isnothing(rxmatch),
                     "\"$content\" does not match any known form for a $component")
        @parseassert(component, length(rxmatch.match) == length(content),
                     "\"$content\" is not just a $component")
        component(rxmatch.captures)
    elseif matcher isa Function
        ErrorException("as $component uses a function matcher, it needs a dedicated " *
            "conversion function to be defined")
    else
        ErrorException("cannot handle $component matcher of type $(typeof(matcher))")
    end
end

# ---------------------
# Org
# ---------------------

function parse(::Type{Org}, content::AbstractString)
    Org(parseorg(content, [Heading, Section]))
end

const OrgElementMatchers =
    Dict{Char, Vector{<:Type}}(
        '#' => [BabelCall, Keyword, Block, Comment],
        '-' => [HorizontalRule, List],
        '|' => [Table],
        ':' => [PropertyDrawer, Drawer, FixedWidth],
        '+' => [List],
        '*' => [List],
        '[' => [FootnoteDef],
        '\\' => [LaTeXEnvironment],
        '\n' => [EmptyLine])

const OrgElementFallbacks = [Paragraph, List]

const OrgObjectMatchers =
    Dict{Char, Vector{<:Type}}(
        '[' => [Link, Timestamp, StatisticsCookie],
        '{' => [Macro],
        '<' => [RadioTarget, Target, Timestamp],
        '\\' => [LineBreak, Entity, LaTeXFragment],
        '*' => [TextMarkup],
        '/' => [TextMarkup],
        '_' => [TextMarkup],
        '+' => [TextMarkup],
        '=' => [TextMarkup],
        '~' => [TextMarkup],
        '@' => [ExportSnippet],
        'c' => [InlineBabelCall, Script, TextPlain],
        's' => [InlineSourceBlock, Script, TextPlain],
        # FootnoteRef
    )

abstract type TextPlainForce end
function consume(::Type{TextPlainForce}, s::AbstractString)
    c = SubString(s, 1, 1)
    # printstyled(stderr, "Warning:", bold=true, color=:yellow)
    # print(stderr, " Force matching ")
    # printstyled(stderr, '\'', c, '\'', color=:cyan)
    # print(stderr, " from ")
    # b = IOBuffer()
    # show(b, s[1:min(50,end)])
    # printstyled(stderr, String(take!(b)), if length(s) > 50 "…" else "" end, color=:green)
    # print(stderr, "\n         This usually indicates a case where the plain text matcher can be improved.\n")
    if c == "\n"
        (c, TextPlain(" "))
    else
        (c, TextPlain(c))
    end
end

const OrgObjectFallbacks =
    [TextPlain,
     TextMarkup,
     Script,
     TextPlainForce] # we *must* move forwards by some ammount, c.f. §4.10

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
                                          1 + section.offset + ncodeunits(plan[1]),
                                          section.offset + section.ncodeunits)
            planning = plan[2]
        end
        props = consume(PropertyDrawer, section)
        if !isnothing(props)
            section = @inbounds SubString(section.string,
                                          1 + section.offset + ncodeunits(props[1]),
                                          section.offset + section.ncodeunits)
            properties = props[2]
        end
        if ncodeunits(section) == 0
            section = nothing
        end
    end
    Heading(level, keyword, priority,
            parseorg(title, OrgObjectMatchers, OrgObjectFallbacks), tagsvec,
            if !isnothing(section) parse(Section, section) end,
            planning, properties)
end

function Section(components::Vector{Union{Nothing, SubString{String}}})
    Section(parseorg(components[1], OrgElementMatchers, OrgElementFallbacks))
end

# ---------------------
# Greater Elements
# ---------------------

# Greater Block

function Drawer(components::Vector{Union{Nothing, SubString{String}}})
    name, content = components
    Drawer(name, parse(Section, content).contents)
end

# Dynamic Block
# FootnoteDef
# InlineTask

function Item(components::Vector{Union{Nothing, SubString{String}}})
    indent, bullet, counterset, checkbox, tag, contents = components
    text = consume(Paragraph, contents)
    sublist = consume(List,
                      if isnothing(text) contents
                      else @inbounds @view contents[1+length(text[1]):end]
                      end)
    Item(bullet, counterset, if !isnothing(checkbox) checkbox[1] end, tag,
         if !isnothing(text) text[2].contents else OrgObject[] end,
         if !isnothing(sublist) sublist[2] end)
end

function List(components::Vector{Union{Nothing, SubString{String}}})
    indent, rest = components
    # since we know that indent and rest are contiguous
    whole = @inbounds SubString(rest.string, 1 + rest.offset - indent.ncodeunits,
                                rest.offset + rest.ncodeunits)
    items = Vector{Item}(parseorg(whole, [Item]))
    if items[1].bullet in ["+", "-", "*"]
        UnorderedList(items)
    else
        OrderedList(items)
    end
end

function PropertyDrawer(components::Vector{Union{Nothing, SubString{String}}})
    nodetext = components[1]
    nodes = parseorg(nodetext, [NodeProperty])
    PropertyDrawer(Vector{NodeProperty}(nodes))
end

function Table(components::Vector{Union{Nothing, SubString{String}}})
    table, tblfms = components
    rows = map(row -> if !isnothing(match(r"^[ \t]*\|[\-\+]+\|*$", row))
                   TableHrule() else parse(TableRow, row, true) end,
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
    lines = split(contents, '\n')
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

function parse(::Type{Planning}, content::AbstractString, verify::Bool=true)
    planning = orgmatcher(Planning)(content)
    verify && @parseassert(Planning, !isnothing(planning),
                           "\"$content\" does not match any recognised form")
    plantext, plan = planning
    verify && @parseassert(Planning, length(plantext) == length(content),
                           "\"$content\" is not just a $component")
    plan
end

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
    name, content = components
    LaTeXEnvironment(name, content)
end

function NodeProperty(components::Vector{Union{Nothing, SubString{String}}})
    name, additive, value = components
    NodeProperty(name, !isnothing(additive), value)
end

function Paragraph(components::Vector{Union{Nothing, SubString{String}}})
    Paragraph(parseorg(components[1], OrgObjectMatchers, OrgObjectFallbacks))
end

function TableRow(components::Vector{Union{Nothing, SubString{String}}})
    split(strip(components[1], '|'), '|') .|> strip .|> TableCell |> TableRow
end

function EmptyLine(_::Vector{Union{Nothing, SubString{String}}})
    EmptyLine()
end

# ---------------------
# Objects
# ---------------------

function parse(::Type{Entity}, content::AbstractString, verify::Bool=true)
    entitymatch = match(r"^\\([A-Za-z]*)({}|[^A-Za-z]|$)", content)
    local name, post
    if !verify
        name, post = entitymatch.captures
    else
        @parseassert(Entitymatch, !isnothing(entitymatch),
                     "\"$content\" is not an Entity")
        name, post = entitymatch.captures
        @parseassert(Entity, name in keys(Entities),
                     "\"$name\" is not a registered in Entities")
    end
    Entity(name, post)
end

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

function FootnoteRef(components::Vector{Union{Nothing, SubString{String}}})
    label, definition = components
    FootnoteRef(label, definition)
end

function InlineBabelCall(components::Vector{Union{Nothing, SubString{String}}})
    name, header1, arguments, header2 = components
    InlineBabelCall(name, if isnothing(header1) header2 else header1 end, arguments)
end

function parse(::Type{InlineSourceBlock}, content::AbstractString, verify::Bool=true)
    srcmatch = match(r"^src_(\S+?)(?:\[([^\n]+)\])?{(.*\n?.*)}$", content)
    if verify
        @parseassert(InlineSourceBlock, !isnothing(srcmatch),
                     "\"$content\" does not match any recognised form")
        codeend = forwardsinlinesrc(content, length(srcmatch.match) - length(srcmatch.captures[3]))
        @parseassert(InlineSourceBlock, codeend == length(srcmatch),
                     "does not end at the end of the input \"$content\"")
    end
    lang, options, code = srcmatch.captures
    InlineSourceBlock(lang, options, code)
end

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
    args = split(arguments, r"(?<!\\), ?")
    Macro(name, if args == [""]; [] else args end)
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
    TableCell(strip(content))
end

function parse(::Type{Timestamp}, content::AbstractString, verify::Bool=true)
    tsmatch = orgmatcher(Timestamp)(content)
    verify && @parseassert(Timestamp, !isnothing(tsmatch),
                           "\"$content\" does not match any recognised form")
    tstext, ts = tsmatch
    verify && @parseassert(Timestamp, length(tstext) == length(content),
                           "\"$content\" is not just a $component")
    ts
end

function parse(T::Type{<:Timestamp}, content::AbstractString, verify::Bool=true)
    ts = parse(Timestamp, content, verify)
    verify && @parseassert(T, ts isa T,
                           "\"$content\" is a $(typeof(ts))")
    ts
end

function parse(::Type{TextPlain}, text::AbstractString, _verify::Bool=false)
    if occursin('\n', text) || occursin("  ", text)
        TextPlain(replace(text, r"[ \t\n]{2,}|\n" => " "))
    else
        TextPlain(text)
    end
end

const TextMarkupMarkers =
    Dict('*' => :bold,
         '/' => :italic,
         '+' => :strikethrough,
         '_' => :underline,
         '=' => :verbatim,
         '~' => :code)

function TextMarkup(components::Vector{Union{Nothing, SubString{String}}})
    pre, marker, contents, post = components
    type = TextMarkupMarkers[marker[1]]
    if type in [:verbatim, :code]
        TextMarkup(type, marker[1], pre, contents, post)
    else
        parsedcontents = parseorg(contents, OrgObjectMatchers, OrgObjectFallbacks)
        TextMarkup(type, marker[1], pre, Vector{OrgObject}(parsedcontents), post)
    end
end

function TextMarkup(marker::Char, pre::AbstractString, content::AbstractString, post::AbstractString)
    @parseassert(TextMarkup, match(r"^(\S.*(?<=\S))$", content),
                 "marked up content \"$content\" cannot start or end with whitespace")
    @parseassert(TextMarkup, match(r"^[\s\-({'\"]?$", pre),
                 "pre must be the start of a line, a whitespace characters, -, (, {, ', or \"")
    @parseassert(TextMarkup, match(r"^[\s\-({'\"]?$", post),
                 "post must be the end of a line, a whitespace character, -, ., ,, ;, :, !, ?, ', ), }, [ or \"")
    type = TextMarkupMarkers[marker]
    if type in [:verbatim, :code]
        TextMarkup(type, marker, pre, content, post)
    else
        parsedcontent = parseorg(content, OrgObjectMatchers, OrgObjectFallbacks)
        TextMarkup(type, marker, pre, parsedcontent, post)
    end
end
