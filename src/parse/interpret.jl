# Methods to interpret string representations of OrgComponents

struct OrgParseError <: Exception
    element::Union{DataType, Nothing}
    msg::AbstractString
end

function Base.showerror(io::IO, ex::OrgParseError)
    print(io, "Org parse error")
    if !isnothing(ex.element)
        print(io, " for component $(ex.element): ")
    else
        print(io, ": ")
    end
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
            throw(OrgParseError($(esc(elem)), $(esc(msg))))
        end
    end
end

include("matchers.jl")

import Base.convert

function convert(component::Type{<:OrgComponent}, content::AbstractString)
    matcher = orgmatcher(component)
    if isnothing(component)
        ErrorException("no matcher is defined for $C")
    end
    if matcher isa Regex
        rxmatch = match(matcher, content)
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
# Sections
# ---------------------

function Heading(components::Vector{Union{Nothing, SubString{String}}})
    stars, keyword, priority, title, tags = components
    level = length(stars)
    tagsvec = if isnothing(tags); [] else split(tags[2:end-1], ':') end
    Heading(level, keyword, priority, title, tagsvec, nothing) # TODO interpret section
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
    bullet, counterset, checkbox, tag, contents = components
    Item(bullet, counterset, if !isnothing(checkbox) checkbox[1] end, tag, contents)
end

# List
# PropertyDrawer

function Table(components::Vector{Union{Nothing, SubString{String}}})
    table, tblfms = components
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

# ---------------------
# Elements
# ---------------------

# Babel Call

function Block(components::Vector{Union{Nothing, SubString{String}}})
    name, data, contents = components
    Block(name, data, contents)
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

Paragraph(content::String) = Paragraph(parseinlineorg(content))

function TableRow(components::Vector{Union{Nothing, SubString{String}}})
    TableRow(TableCell.(split(strip(components[1], '|'), '|')))
end

# ---------------------
# Objects
# ---------------------

function convert(::Type{Entity}, content::AbstractString)
    entitymatch = match(r"^\\([A-Za-z]*)({}|[^A-Za-z]|$)", content)
    @parseassert(Entitymatch, !isnothing(entitymatch),
                 "\"$content\" is not an Entity")
    name, post = entitymatch.captures
    @parseassert(Entity, name in keys(Entities),
                 "\"$name\" is not a registered in Entities")
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

function InlineSourceBlock(components::Vector{Union{Nothing, SubString{String}}})
    name, options, arguments = components
    InlineSourceBlock(name, options, arguments)
end

function LineBreak(_components::Vector{Union{Nothing, SubString{String}}})
    LineBreak()
end

function convert(::Type{LinkPath}, content::AbstractString)
    protocolmatch = match(r"^([^#*\s:]+):(?://)?(.*)$", content)
    if isnothing(protocolmatch)
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
        LinkPath(protocol, path)
    end
end

function Link(components::Vector{Union{Nothing, SubString{String}}})
    path, description = components
    Link(convert(LinkPath, path), description)
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
    RadioTarget()
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

function convert(::Type{Timestamp}, content::AbstractString)
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
    throw(OrgParseError(Timestamp, "$content did not match any recognised forms"))
end

Base.convert(::Type{TextPlain}, text::AbstractString) = TextPlain(text)

function gobbletextplain(content::AbstractString)
    text = match(r"^[A-Za-z][^\n_^\.{}\[\]\\*\/+_~=]*[A-Za-z]", content)
    if !isnothing(text)
        if occursin(' ', text.match)
            content[1:findlast(' ', text.match)-1]
        else
            text.match
        end
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
    TextMarkup(type, marker[1], pre, parseinlineorg(contents), post)
end

function TextMarkup(marker::Char, pre::AbstractString, content::AbstractString, post::AbstractString)
    @parseassert(TextMarkup, match(r"^(\S.*(?<=\S))$", content),
                 "marked up content \"$content\" cannot start or end with whitespace")
    @parseassert(TextMarkup, match(r"^[\s\-({'\"]?$", pre),
                 "pre must be the start of a line, a whitespace characters, -, (, {, ', or \"")
    @parseassert(TextMarkup, match(r"^[\s\-({'\"]?$", post),
                 "post must be the end of a line, a whitespace character, -, ., ,, ;, :, !, ?, ', ), }, [ or \"")
    type = TextMarkupMarkers[marker]
    TextMarkup(type, marker, pre, parseinlineorg(contents), post)
end
