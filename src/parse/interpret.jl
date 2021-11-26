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

# ---------------------
# Sections
# ---------------------

function Heading(components::Vector{Union{Nothing, SubString{String}}})
    stars, keyword, priority, title, tags, section = components
    level = length(stars)
    tagsvec = if isnothing(tags); [] else split(tags[2:end-1], ':') end
    Heading(level, keyword, priority, title, tagsvec,
            if !isnothing(section) parse(Section, section) end)
end

const SectionInnerTypeMatchers =
    Dict('#' => [BabelCall, Keyword, Block, Comment],
         '-' => [HorizontalRule, List],
         '|' => [Table],
         # ':' => [PropertyDrawer, Drawer, FixedWidth],
         '+' => [List],
         '*' => [List],
         '[' => [FootnoteDef],
         '\\' => [LaTeXEnvironment],
         '\n' => [EmptyLine])

const SectionInnerTypeFallbacks = [Paragraph]

function Section(components::Vector{Union{Nothing, SubString{String}}})
    Section(parseorg(components[1], SectionInnerTypeMatchers, SectionInnerTypeFallbacks))
end

# ---------------------
# Greater Elements
# ---------------------

# Greater Block
# Drawer
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
         if !isnothing(text) text[2].objects end,
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

# PropertyDrawer

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
    if name == "src"
        local lang, arguments
        if isnothing(data)
            lang, arguments = nothing, nothing
        else
            lang, arguments = match(r"^(\S+)( [^\n]+)?$", data).captures
        end
        SourceBlock(lang, arguments, contents)
    elseif name == "example"
        ExampleBlock(contents)
    else
        CustomBlock(name, data, contents)
    end
end

# DiarySexp
# Comment
# Fixed Width
# Horizontal Rule

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
    NodeProperty(name, isnothing(additive), value)
end

const ParagraphInnerTypeMatchers =
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
        # Timestamp
    )

const ParagraphInnerTypeFallbacks =
    [Script,
     TextPlain,
     TextMarkup,
     TextPlainForce] # we *must* move forwards by some ammount, c.f. §4.10

function Paragraph(components::Vector{Union{Nothing, SubString{String}}})
    Paragraph(parseorg(components[1], ParagraphInnerTypeMatchers, ParagraphInnerTypeFallbacks))
end

function TableRow(components::Vector{Union{Nothing, SubString{String}}})
    TableRow(TableCell.(split(strip(components[1], '|'), '|')))
end

function EmptyLine(_components::Vector{Union{Nothing, SubString{String}}})
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
    srcmatch = match(r"^src_(\S+?)(?:\[([^\n]+)\])?{(.*)}$", content)
    if verify
        @parseassert(InlineSourceBlock, !isnothing(srcmatch),
                     "\"$content\" does not match any recognised form.")
        codeend = forwardsinlinesrc(content, length(srcmatch.match) - length(srcmatch.captures[3]))
        @parseassert(InlineSourceBlock, codeend == length(srcmatch),
                     "does not end at the end of the input \"$content\"")
    end
    lang, options, code = srcmatch.captures
    InlineSourceBlock(lang, options, code)
end

function LineBreak(_components::Vector{Union{Nothing, SubString{String}}})
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
    RadioTarget(target)
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

# Table Cell

function parse(::Type{Timestamp}, content::AbstractString, _verify::Bool)
    function DateTimeRD(type, date, time, mark, value, unit)
        type(Date(date),
             if isnothing(time) nothing else Time(time) end,
             if isnothing(mark) nothing else TimestampRepeaterOrDelay(mark, value, unit[1]) end)
    end
    open, bra, ket = "(?:(<)|\\[)", "(?(1)<|\\[)", "(?(1)>|\\])"
    date = "(\\d{4}-\\d\\d-\\d\\d)(?: [A-Za-z]{3,7})?"
    time = "(\\d?\\d:\\d\\d)"
    repeater_or_delay = "((?:\\+|\\+\\+|\\.\\+|-|--))([\\d.]+)([hdwmy])"
    # <%%(SEXP)>
    diarymatch = match(r"^<%%\((.*)\)>$", content)
    if !isnothing(diarymatch)
        return TimestampDiary(diarymatch.captures[1])
    end
    # <DATE TIME REPEATER-OR-DELAY>
    singletsmatch = match(Regex("^$open$date(?: $time)?(?: $repeater_or_delay)?$ket\$"), content)
    if !isnothing(singletsmatch)
        activep, date, time, mark, value, unit = singletsmatch.captures
        type = if isnothing(activep) TimestampInactive else TimestampActive end
        return DateTimeRD(type, date, time, mark, value, unit)
    end
    # <DATE TIME REPEATER-OR-DELAY>--<DATE TIME REPEATER-OR-DELAY>
    doubletsmatch = match(Regex("^$open$date(?: $time)?(?: $repeater_or_delay)?$ket--$bra$date(?: $time)?(?: $repeater_or_delay)?$ket\$"), content)
    if !isnothing(doubletsmatch)
        activep, date1, time1, mark1, value1, unit1, date2, time2, mark2, value2, unit2 = doubletsmatch.captures
        type = if isnothing(activep) TimestampInactive else TimestampActive end
        range = if isnothing(activep) TimestampInactiveRange else TimestampActiveRange end
        return range(DateTimeRD(type, date1, time1, mark1, value1, unit1),
                     DateTimeRD(type, date2, time2, mark2, value2, unit2))
    end
    # <DATE TIME-TIME REPEATER-OR-DELAY>
    doubletimematch = match(Regex("^$open$date $time-$time(?: $repeater_or_delay)?$ket\$"), content)
    if !isnothing(doubletimematch)
        activep, date, time1, time2, mark, value, unit = doubletimematch.captures
        type = if isnothing(activep) TimestampInactive else TimestampActive end
        range = if isnothing(activep) TimestampInactiveRange else TimestampActiveRange end
        return range(DateTimeRD(type, date, time1, mark, value, unit),
                     DateTimeRD(type, date, time1, mark, value, unit))
    end
    throw(OrgComponentParseError(Timestamp, "$content did not match any recognised forms"))
end

function Base.parse(::Type{TextPlain}, text::AbstractString, _verify::Bool=false)
    if occursin('\n', text) || occursin("  ", text)
        TextPlain(replace(text, r"[ \t]{2,}|\n" => " "))
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
        TextMarkup(type, marker[1], pre, parse(Paragraph, contents).objects, post)
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
        TextMarkup(type, marker, pre, contents, post)
    else
        TextMarkup(type, marker, pre, parse(Paragraph, contents).objects, post)
    end
end
