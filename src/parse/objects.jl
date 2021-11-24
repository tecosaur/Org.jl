using Dates

abstract type OrgObject <: OrgComponent end

include("../data/entities.jl")
mutable struct OrgEntity <: OrgObject # Org Syntax §5.1
    name::AbstractString
    post::AbstractString
end
const OrgEntityRegex = r"\\([A-Za-z]*)(.*)"
function OrgEntity(content::AbstractString)
    @parseassert(OrgEntity, match(r"^\\[A-Za-z]", content),
                 "entity \"$content\" should start with \"\\\" followed by an alphabetical character")
    @parseassert(OrgEntity, match(r"^\\[A-Za-z]", content),
                 "entity \"$content\" can only contain alphabetical characters")
    name, post = match(r"^\\([A-Za-z]*)(.*)", content).captures
    @parseassert(OrgEntity, name in keys(Entities),
                 "\"$name\" is not a registered in Entities")
    @parseassert(OrgEntity, match(r"^|{}|[^A-Za-z]$", content),
                 "entity \"$content\" must be followed a line end, \"{}\", or a non-alphabetical character")
    OrgEntity(name, post)
end

mutable struct LaTeXFragment <: OrgObject # Org Syntax §5.1
    contents::AbstractString
    delimiters::Union{Tuple{AbstractString, AbstractString}, Nothing}
end
const LaTeXFragmentRegex = r"\\[A-Za-z]+(?:{.*})?|\\\(.*?\\\)|\\[.*?\\]"
function LaTeXFragment(content::AbstractString)
    entitymatch = match(r"^\\([A-Za-z]+)((?:{})?)$", content)
    if !isnothing(entitymatch)
        name, arg = entitymatch.captures
        if name in keys(Entities)
            OrgEntity(name, arg)
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

mutable struct ExportSnippet <: OrgObject # Org Syntax §5.2
    # @@BACKEND:CONTENT@@
    backend::AbstractString # contains any alpha-numeric character and hyphens
    snippet::AbstractString # contains anything but “@@” string
end
const ExportSnippetRegex = r"\@\@.+:.*?\@\@"
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

mutable struct FootnoteRef <: OrgObject # Org Syntax §5.3
    # [fn:LABEL]
    # [fn:LABEL:DEFINITION]
    # [fn::DEFINITION]
    label::Union{AbstractString, Nothing}
    definition::Union{AbstractString, Nothing}
end
const FootnoteRefRegex = r"\[fn:(?:[^:]+|:.+|[^:]+:.+)\]"
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

mutable struct InlineBabelCall <: OrgObject # Org Syntax §5.4
    # call_NAME[HEADER](ARGUMENTS)[HEADER]
    name::AbstractString
    header::Union{AbstractString, Nothing}
    arguments::Union{AbstractString, Nothing}
end
const InlineBabelCallRegex = r"call_([^()\n]+?)(?:(\[[^]\n]+\]))?\(([^)\n]*)\)(?:(\[[^]\n]+\]))?"
function InlineBabelCall(content::AbstractString)
    babelcallmatch = match(r"^call_([^()\n]+?)(?:(\[[^]\n]+\]))?\(([^)\n]*)\)(?:(\[[^]\n]+\]))?$", content)
    if isnothing(babelcallmatch)
        throw(OrgParseError(InlineBabelCall, "$content did not match any recognised forms"))
    end
    name, header1, arguments, header2 = babelcallmatch.captures
    InlineBabelCall(name, if isnothing(header1) header2 else header1 end, arguments)
end

mutable struct InlineSourceBlock <: OrgObject # Org Syntax §5.4
    # src_LANG[OPTIONS]{BODY}
    lang::AbstractString
    options::Union{AbstractString, Nothing}
    body::AbstractString
end
const InlineSourceBlockRegex = r"src_(\S+?)(?:(\[[^\n]+\]))?{([^\n]*)}"
function InlineSourceBlock(content::AbstractString)
    inlinesrcmatch = match(r"^src_(\S+?)(?:(\[[^\n]+\]))?{([^\n]*)}$", content)
    if isnothing(inlinesrcmatch)
        throw(OrgParseError(InlineBabelCall, "$content did not match any recognised forms"))
    end
    name, options, arguments = inlinesrcmatch.captures
    InlineBabelCall(name, options, arguments)
end

mutable struct LinkPath <: OrgObject # Org Syntax §5.5
    protocol::Union{Symbol, AbstractString}
    path::AbstractString
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

struct LineBreak <: OrgObject end # Org Syntax §5.5
# \\INSIGNIFICANT_OPTIONAL_WHITESPACE
const LineBreakRegex = r"\\\\\s*(?:\n *|$)"

mutable struct Link <: OrgObject # Org Syntax §5.6
    # [[PATH]]
    # [[PATH][DESCRIPTION]]
    path::LinkPath
    description::Union{AbstractString, Nothing}
end
const LinkRegex = r"\[\[([^]]+)\](?:\[([^]]+)\])?\]"
function Link(content::AbstractString)
    linkmatch = match(r"^\[\[([^]]+)\](?:\[([^]]+)\])?\]$", content)
    @parseassert(Link, !isnothing(linkmatch),
                 "$content did not match any recognised forms")
    path, description = linkmatch.captures
    Link(LinkPath(path), description)
end

mutable struct Macro <: OrgObject # Org Syntax §5.7
    # {{{NAME(ARGUMENTS)}}}
    name::AbstractString
    arguments::Vector{AbstractString}
end
const MacroRegex = r"{{{([A-Za-z][A-Za-z0-9-_]*)\((.*)\)}}}"
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

mutable struct RadioTarget <: OrgObject # Org Syntax §5.8
    # <<<CONTENTS>>>
    contents::AbstractString
    # contents::Vector{Union{TextMarkup, OrgEntity, LaTeXFragment, Subscript, Superscript}}
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
end
const RadioTargetRegex = r"<<<.*?>>>"

mutable struct Target <: OrgObject # Org Syntax §5.8
    # <<TARGET>>
    target::AbstractString
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
end
const TargetRegex = r"<<.*?>>"

abstract type StatisticsCookie <: OrgObject end # Org Syntax §5.9
mutable struct StatisticsCookiePercent <: StatisticsCookie
    # [PERCENTAGE%]
    percentage::AbstractString
end
mutable struct StatisticsCookieFraction <: StatisticsCookie
    # [COMPLETE/TOTAL]
    complete::Integer
    total::Integer
end
const StatisticsCookieRegex = r"\[(?:[\d.]*%|\d*/\d*)\]"
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

abstract type Script <: OrgObject end # Org Syntax §5.10
mutable struct Subscript <: Script
    char::Char
    script::AbstractString
end
mutable struct Superscript <: Script
    char::Char
    script::AbstractString
end
const ScriptRegex = r"(\S)([_^])({.*}|[+-][A-Za-z0-9-\\.]*[A-Za-z0-9])"
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

mutable struct TableCell <: OrgObject # Org Syntax §5.11
    contents::AbstractString
    function TableCell(content::AbstractString)
        @parseassert(TableCell, !occursin("|", content),
                     "\"$content\" cannot contain \"|\"")
        new(strip(content))
    end
end
Base.length(cell::TableCell) = length(cell.contents)

abstract type Timestamp <: OrgObject end # Org Syntax §5.12
mutable struct TimestampRepeaterOrDelay
    mark::AbstractString
    value::AbstractString
    unit::Char
end
mutable struct TimestampDiary <: Timestamp
    sexp::AbstractString
end
mutable struct TimestampActive <: Timestamp
    date::Date
    time::Union{Time, Nothing}
    repeater::Union{TimestampRepeaterOrDelay, Nothing}
end
const TimestampActiveRegex = r"<\d{4}-\d\d-\d\d(?: \d?\d:\d\d)?(?: [A-Za-z]{3,7})?>"
mutable struct TimestampInactive <: Timestamp
    date::Date
    time::Union{Time, Nothing}
    repeater::Union{TimestampRepeaterOrDelay, Nothing}
end
const TimestampInactiveRegex = r"\[\d{4}-\d\d-\d\d(?: \d?\d:\d\d)?(?: [A-Za-z]{3,7})?\]"
mutable struct TimestampActiveRange <: Timestamp
    start::TimestampActive
    stop::TimestampActive
end
mutable struct TimestampInactiveRange <: Timestamp
    start::TimestampInactive
    stop::TimestampInactive
end
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

mutable struct TextPlain <: OrgObject
    text::AbstractString
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

mutable struct TextMarkup <: OrgObject # Org Syntax §5.13
    type::Symbol
    marker::Char
    pre::AbstractString
    contents::Vector{OrgObject}
    post::AbstractString
end
const TextMarkupMarkers =
    Dict('*' => :bold,
         '/' => :italic,
         '+' => :strikethrough,
         '_' => :underline,
         '=' => :verbatim,
         '~' => :code)
const TextMarkupRegex = r"(^|[\s\-({'\"])([*\/+_~=])(\S.*?(?<=\S))\2([]\s\-.,;:!?')}\"]|$)"m
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
TextMarkup(marker::Char, content::AbstractString) = TextMarkup(marker, "", content, "")

Bold(content::AbstractString) = TextMarkup('*', content)
Italic(content::AbstractString) = TextMarkup('/', content)
Strikethrough(content::AbstractString) = TextMarkup('+', content)
Underline(content::AbstractString) = TextMarkup('_', content)
Code(content::AbstractString) = TextMarkup('~', content)
