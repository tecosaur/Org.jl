# Methods to interpret string representations of OrgComponents

struct OrgParseError <: Exception
    element::Union{DataType, Nothing}
    msg::AbstractString
end

function Base.showerror(io::IO, ex::OrgParseError)
    print(io, "Org parse error")
    if !isnothing(ex.element)
        print(io, " in element $(ex.element): ")
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

include("regex.jl")

# ---------------------
# Sections
# ---------------------

function Heading(content::AbstractString)
    headingmatch = match(HeadingRegex, content)
    @parseassert(Heading, !isnothing(headingmatch),
                 "\"$content\" did not match any recognised form")
    stars, keyword, priority, title, tags = headingmatch.captures
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

function Item(content::AbstractString)
    itemmatch = match(ItemRegex, content)
    @parseassert(Item, !inothing(itemmatch),
                 "\"$content\" did not match any recognised form")
    bullet, counterset, checkbox, tag, contents = itemmatch.captures
    Item(bullet, counterset, if !isnothing(checkbox) checkbox[1] end, tag, contents)
end

# List
# PropertyDrawer

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

# ---------------------
# Elements
# ---------------------

# Babel Call

function Block(content::AbstractString)
    blockmatch = match(Regex("^$(BlockRegexp.pattern)"), content)
    @parseassert(Block, !isnothing(blockmatch),
                 "did not match any recognised block form\n$content")
    name, data, contents = blockmatch.captures
    Block(name, data, contents)
end

# DiarySexp
# Comment
# Fixed Width
# Horizontal Rule

function Keyword(content::AbstractString)
    keywordmatch = match(KeywordRegex, content)
    @parseassert(Keyword, !isnothing(keywordmatch),
                 "\"$content\"did not match any recognised form")
    key, value = keywordmatch.captures
    Keyword(key, value)
end

function LaTeXEnvironment(content::AbstractString)
    latexenvmatch = match(LaTeXEnvironmentRegex, content)
    @parseassert(LaTeXEnvironment, !isnothing(latexenvmatch),
                 "did not match any recognised form\n$content")
    name, content = latexenvmatch.captures
    LaTeXEnvironment(name, content)
end

function NodeProperty(content::AbstractString)
    nodepropmatch = match(NodeProperty, content)
    @parseassert(NodeProperty, !isnothing(nodepropmatch),
                 "\"$content\" did not match any recognised form")
    name, additive, value = nodepropmatch.captures
    NodeProperty(name, isnothing(additive), value)
end

Paragraph(content::String) = Paragraph(parseinlineorg(content))

function TableRow(content::AbstractString)
    TableRow(TableCell.(split(strip(content, '|'), '|')))
end

# ---------------------
# Objects
# ---------------------

function Entity(content::AbstractString)
    @parseassert(Entity, match(r"^\\[A-Za-z]", content),
                 "entity \"$content\" should start with \"\\\" followed by an alphabetical character")
    @parseassert(Entity, match(r"^\\[A-Za-z]", content),
                 "entity \"$content\" can only contain alphabetical characters")
    name, post = match(r"^\\([A-Za-z]*)(.*)", content).captures
    @parseassert(Entity, name in keys(Entities),
                 "\"$name\" is not a registered in Entities")
    @parseassert(Entity, match(r"^|{}|[^A-Za-z]$", content),
                 "entity \"$content\" must be followed a line end, \"{}\", or a non-alphabetical character")
    Entity(name, post)
end

function LaTeXFragment(content::AbstractString)
    entitymatch = match(r"^\\([A-Za-z]+)((?:{})?)$", content)
    if !isnothing(entitymatch)
        name, arg = entitymatch.captures
        if name in keys(Entities)
            Entity(name, arg)
        else
            LaTeXFragment(content, nothing)
        end
    elseif !isnothing(match(r"^\\[A-Za-z]+(?:{[^][{}\n]*}|\[[^][{}\n]*\])*$", content))
        LaTeXFragment(content, nothing)
    elseif !isnothing(match(r"^\\\(.*\\\)", content))
        @parseassert(LaTeXFragment, !match(r"\\\).*\\\)", content),
                     "cannot contain \"\\)\" within the delimiters.")
        @parseassert(LaTeXFragment, !occursin("\n\n", content),
                     "cannot contain a blank line")
        LaTeXFragment(content, ("\\(", "\\)"))
    elseif !isnothing(match(r"^\\\[.*\\\]", content))
        @parseassert(LaTeXFragment, !match(r"\\\].*\\\]", content),
                     "cannot contain \"\\]\" within the delimiters.")
        @parseassert(LaTeXFragment, !occursin("\n\n", content),
                     "cannot contain a blank line")
        LaTeXFragment(content, ("\\[", "\\]"))
        # I don't like $ / $$, so let's not parse them for now
    else
        throw(OrgParseError(LaTeXFragment, "\"$content\" does not follow a recognised form."))
    end
end

function ExportSnippet(content::AbstractString)
    @parseassert(ExportSnippet, match(r"^\@\@.+\@\@$", content),
                 "\"$content\" should be surrounded by @@...@@")
    backend, snippet = split(content[3:end-2], ":", limit=2)
    @parseassert(ExportSnippet, match(r"^[A-Za-z0-9-]+$", backend),
                 "backend \"$backend\" can only contain alpha-numeric characters and hyphens")
    @parseassert(ExportSnippet, !occursin("@@", snippet),
                 "snippet \"$snippet\" cannot contain \"@@\".")
    ExportSnippet(backend, snippet)
end

function FootnoteRef(content::AbstractString)
    if !isnothing(match(r"^\[fn:[^:]+\]$", content))
        FootnoteRef(content[5:end-1], nothing)
    elseif !isnothing(match(r"^\[fn::.+\]$", content))
        FootnoteRef(nothing, content[5:end-1])
    elseif !isnothing(match(r"^\[fn:[^:]+:.+\]", content))
        label, definition = split(content[5:end-1], ':', limit=2)
        FootnoteRef(label, definition)
    else
        throw(OrgParseError(FootnoteRef, "$content did not match any recognised forms"))
    end
end

function InlineBabelCall(content::AbstractString)
    babelcallmatch = match(r"^call_([^()\n]+?)(?:(\[[^]\n]+\]))?\(([^)\n]*)\)(?:(\[[^]\n]+\]))?$", content)
    if isnothing(babelcallmatch)
        throw(OrgParseError(InlineBabelCall, "$content did not match any recognised forms"))
    end
    name, header1, arguments, header2 = babelcallmatch.captures
    InlineBabelCall(name, if isnothing(header1) header2 else header1 end, arguments)
end

function InlineSourceBlock(content::AbstractString)
    inlinesrcmatch = match(r"^src_(\S+?)(?:(\[[^\n]+\]))?{([^\n]*)}$", content)
    if isnothing(inlinesrcmatch)
        throw(OrgParseError(InlineBabelCall, "$content did not match any recognised forms"))
    end
    name, options, arguments = inlinesrcmatch.captures
    InlineBabelCall(name, options, arguments)
end

function LinkPath(content::AbstractString)
    protocolmatch = match(r"^([^#*\s:]+):(?://)?(.*)$", content)
    if isnothing(protocolmatch)
        if !isnothing(match(r"^\(.+\)$", content))
            LinkPath(:coderef, content[2:end-1])
        elseif !isnothing(match(r"^#", content))
            LinkPath(:custom_id, content[2:end])
        elseif !isnothing(match(r"^\*", content))
            LinkPath(:heading, content[2:end])
        else
            LinkPath(:fuzzy, content)
        end
    else
        protocol, path = protocolmatch.captures
        LinkPath(protocol, path)
    end
end

function Link(content::AbstractString)
    linkmatch = match(r"^\[\[([^]]+)\](?:\[([^]]+)\])?\]$", content)
    @parseassert(Link, !isnothing(linkmatch),
                 "$content did not match any recognised forms")
    path, description = linkmatch.captures
    Link(LinkPath(path), description)
end

function Macro(content::AbstractString)
    macromatch = match(r"^{{{([A-Za-z][A-Za-z0-9-_]*)\((.*)\)}}}$", content)
    @parseassert(Macro, !isnothing(macromatch),
                 "$content did not match any recognised forms")
    name, arguments = macromatch.captures
    @parseassert(Macro, !occursin("}}}", arguments),
                 "arguments \"$arguments\" cannot contain \"}}}\"")
    args = split(arguments, r"(?<!\\), ?")
    Macro(name, if args == [""]; [] else args end)
end

function RadioTarget(contents::AbstractString)
    radiotargetmatch = match(r"^<<<(.*)>>>$", contents)
    if isnothing(radiotargetmatch)
        throw(OrgParseError(RadioTarget, "$contents must be wraped with <<<...>>>"))
    end
    target = radiotargetmatch.captures[1]
    @parseassert(RadioTarget, match(r"^[^<>\n]*$", target),
                    "\"$target\" cannot contain <, >, or \\n")
    @parseassert(RadioTarget, !match(r"^\s|\s$", target),
                    "\"$target\" cannot start or end with whitespace")
    new(target)
end

function Target(contents::AbstractString)
    targetmatch = match(r"^<<(.*)>>$", contents)
    if isnothing(targetmatch)
        throw(OrgParseError(Target, "$contents must be wraped with <<...>>"))
    end
    target = targetmatch.captures[1]
    @parseassert(Target, match(r"^[^<>\n]*$", target),
                    "\"$target\" cannot contain <, >, or \\n")
    @parseassert(Target, !match(r"^\s|\s$", target),
                    "\"$target\" cannot start or end with whitespace")
    new(target)
end

function StatisticsCookie(content::AbstractString)
    # TODO support uninitialised cookies, i.e. [%] or [/]
    percentmatch = match(r"^\[([\d.]*)%\]$", content)
    fracmatch = if isnothing(percentmatch) match(r"^\[(\d*)/(\d*)\]$", content) end
    if !isnothing(percentmatch)
        StatisticsCookiePercent(percentmatch.captures[1])
    elseif !isnothing(fracmatch)
        num, denom = fracmatch.captures
        StatisticsCookieFraction(parse(Int, num), parse(Int, denom))
    else
        throw(OrgParseError(StatisticsCookie, "$content did not match any recognised forms"))
    end
end

function Script(content::AbstractString)
    scriptmatch = match(r"^(\S)([_^])({.*}|[+-]?[A-Za-z0-9-\\.]*[A-Za-z0-9])$", content)
    @parseassert(Script, !isnothing(scriptmatch),
                 "$content did not match any recognised forms")
    char, type, script = scriptmatch.captures
    if type == "^"
        Superscript(char[1], script)
    else
        Subscript(char[1], script)
    end
end

# Table Cell

function Timestamp(content::AbstractString)
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

function TextMarkup(content::AbstractString)
    textmatch = match(r"^([\s\-({'\"]?)([*\/+_~=])(\S.*?(?<=\S))\2([]\s\-.,;:!?')}\"$]?)$", content)
    @parseassert(TextMarkup, !isnothing(textmatch),
                 "\"$content\" is not a valid markup element")
    pre, marker, contents, post = textmatch.captures
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
