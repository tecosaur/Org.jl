using Dates

abstract type OrgObject <: OrgComponent end

include("../data/entities.jl")
@doc org"""
*Org Syntax Reference*: \S5.1 \\
*Org Component Name*: Entity

* Form
#+begin_src org
\NAME POST
#+end_src

- =NAME= is a key of ~Entities~.
- =POST= may be an EOL, "{}", or a non-alphabetical character.

=NAME= and =POST= are /not/ seperated by whitespace.

* Fields
#+begin_src julia
name::AbstractString
post::AbstractString
#+end_src
"""
mutable struct OrgEntity <: OrgObject
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

@doc org"""
*Org Syntax Reference*: \S5.1 \\
*Org Component Type*: Object

* Forms
#+begin_src org
\NAME BRACKETS
\(CONTENTS\)
\[CONTENTS\]
# some other forms I don't like
#+end_src

- =NAME= contains alphabetical characters only
- =BRACKETS= is optional, and not seperated from =NAME= by whitespace.
- =CONTENTS= can contain any charachters, but not the closing delimiter
  or a double newline (blank line)

* Fields
#+begin_src julia
contents::AbstractString
delimiters::Union{Tuple{AbstractString, AbstractString}, Nothing}
#+end_src
"""
mutable struct LaTeXFragment <: OrgObject
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

@doc org"""
*Org Syntax Reference*: \S5.2 \\
*Org Component Type*: Object

* Form
#+begin_src org
@@BACKEND:SNIPPET@@
#+end_src

- =BACKEND= can contain any alphanumeric charachter, and hyphens
- =SNIPPET= can contain anything but the "@@" string

* Fields
#+begin_src julia
backend::AbstractString
snippet::AbstractString
#+end_src
"""
mutable struct ExportSnippet <: OrgObject
    backend::AbstractString
    snippet::AbstractString
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

@doc org"""
*Org Syntax Reference*: \S5.3 \\
*Org Component Type*: Object

* Forms
#+begin_src org
[fn:LABEL]
[fn:LABEL:DEFINITION]
[fn::DEFINITION]
#+end_src

- =LABEL= can contain any word-constituent character, hyphens, and underscores
- =DEFINITION= can contain any charachter, any any object encountered in a =Paragraph=
  even other footnote references. The opening and closing square brackets must be balenced.

* Fields
#+begin_src julia
label::Union{AbstractString, Nothing}
definition::OrgObject[]
#+end_src
"""
mutable struct FootnoteRef <: OrgObject
    label::Union{AbstractString, Nothing}
    definition::Vector{OrgObject}
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

@doc org"""
*Org Syntax Reference*: \S5.4 \\
*Org Component Type*: Object

* Forms
#+begin_src org
call_NAME(ARGUMENTS)
call_NAME[HEADER](ARGUMENTS)[HEADER]
#+end_src

- =NAME= can contain any charachter besides "(", ")", and "\\n"
- =ARGUMENTS= can contain any charachter besides ")" and "\\n"
- =HEADER= can contain any character besides "]" and "\\n"

* Fields
#+begin_src julia
name::AbstractString
header::Union{AbstractString, Nothing}
arguments::Union{AbstractString, Nothing}
#+end_src
"""
mutable struct InlineBabelCall <: OrgObject
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

@doc org"""
*Org Syntax Reference*: \S5.4 \\
*Org Component Type*: Object

* Forms
#+begin_src org
src_LANG{BODY}
src_LANG[OPTIONS]{BODY}
#+end_src

- =LANG= can contain any non-whitespace character
- =BODY= and =OPTIONS= can contain any character but "\\n"

* Fields
#+begin_src julia
lang::AbstractString
options::Union{AbstractString, Nothing}
body::AbstractString
#+end_src
"""
mutable struct InlineSourceBlock <: OrgObject
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

@doc org"""
*Org Syntax Reference*: \S5.5 \\
*Org Component Type*: Object

* Forms
#+begin_src org
\\SPACE
#+end_src

- =SPACE= can contain any number of tabs and spaces, including zero.

This pattern must occur at the end of any otherwise non-empty line.
"""
struct LineBreak <: OrgObject end
const LineBreakRegex = r"\\\\\s*(?:\n *|$)"

@doc org"""
*Org Syntax Reference*: \S5.6 \\
*Org Component Type*: Object

* Forms
#+begin_src org
PROTOCOL:PATH
PROTOCOL://PATH
id::ID
#CUSTOM-ID
(CODEREF)
FUZZY
#+end_src

- =PROTOCOL= is any recognised protocol string
- =PATH=, =CUSTOM-ID=, =CODEREF=, and =FUZZY= can contain any character besides "[" or "]"
- =ID= is a hexidecimal string seperated by hyphens

* Fields
#+begin_src julia
protocol::Union{Symbol, AbstractString}
path::AbstractString
#+end_src
"""
mutable struct LinkPath <: OrgObject
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

@doc org"""
*Org Syntax Reference*: \S5.6 \\
*Org Component Type*: Object

* Forms
#+begin_src org
[[LINKPATH]]
[[LINKPATH][DESCRIPTION]]
<LINKPATH> # currently unsupported
PRE1 RADIO POST1 # currently unsupported
PRE2 LINKPATH POST2 # currently unsupported
#+end_src

- =LINKPATH= is descriped by =LinkPath=
- =DESCRIPTION= can contain any character but square brackets
- =PRE1= and =POST1= are non-alphanumeric characters
- =PRE2= and =POST2= are non-word-constituent characters
- =RADIO= is a string matched by some =RadioTarget=

* Fields
#+begin_src julia
path::LinkPath
description::Union{AbstractString, Nothing}
#+end_src
"""
mutable struct Link <: OrgObject
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

@doc org"""
*Org Syntax Reference*: \S5.7 \\
*Org Component Type*: Object

* Forms
#+begin_src org
{{{NAME(ARGUMENTS)}}}
#+end_src

- =NAME= must start with a letter can be followed by any number of
  alpha-numeric characters, hyphens and underscores.
- =ARGUMENTS= can contain anything but “}}}” string.
  Values within ARGUMENTS are separated by commas.
  Non-separating commas have to be escaped with a backslash character.

* Fields
#+begin_src julia
name::AbstractString
arguments::Vector{AbstractString}
#+end_src
"""
mutable struct Macro <: OrgObject
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

@doc org"""
*Org Syntax Reference*: \S5.8 \\
*Org Component Type*: Object

* Forms
#+begin_src org
<<<CONTENTS>>>
#+end_src

- =CONTENTS= can be any character besides "<", ">" and "\\n",
  but cannot start or end with whitespace.

* Fields
#+begin_src julia
contents::AbstractString
#+end_src
"""
mutable struct RadioTarget <: OrgObject
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

@doc org"""
*Org Syntax Reference*: \S5.8 \\
*Org Component Type*: Object

* Forms
#+begin_src org
<<CONTENTS>>
#+end_src

- =CONTENTS= can be any character besides "<", ">" and "\\n",
  but cannot start or end with whitespace. It cannot contain any objects.

* Fields
#+begin_src julia
contents::AbstractString
#+end_src
"""
mutable struct Target <: OrgObject
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

@doc org"""
*Org Syntax Reference*: \S5.9 \\
*Org Component Type*: Object

* Forms
#+begin_src org
[PERCENTAGE%]
[COMPLETE/TOTAL]
#+end_src

- =PERCENTAGE=, =COMPLETE=, and =TOTAL= are numbers or an empty string.

* Fields
The subtype =StatisticsCookiePercent= has the following structure:
#+begin_src
percentage::AbstractString
#+begin_src
The subtype =StatisticsCookieFraction= has the following structure:
#+begin_src
complete::Union{Integer, Nothing}
total::Union{Integer, Nothing}
#+end_src
"""
abstract type StatisticsCookie <: OrgObject end
@doc org"""
See =StatisticsCookie=.
"""
mutable struct StatisticsCookiePercent <: StatisticsCookie
    percentage::AbstractString
end
@doc org"""
See =StatisticsCookie=.
"""
mutable struct StatisticsCookieFraction <: StatisticsCookie
    complete::Union{Integer, Nothing}
    total::Union{Integer, Nothing}
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

@doc org"""
*Org Syntax Reference*: \S5.10 \\
*Org Component Type*: Object

* Forms
#+begin_src org
CHAR_SCRIPT
CHAR^SCRIPT
#+end_src

- =CHAR= is any non-whitespace character
- =SCRIPT= is either:
  - "*"
  - An expresion enclosed in curly brackets "{...}", which can itself
    contain balenced parenthesis
  - A pattern =SIGN CHARS FINAL= (without the whitespace), where
    - =SIGN= is either "+", "-", or ""
    - =CHARS= is any number of alpha-numeric characters, commas,
      backslashes and dots, or the empty string.
    - =FINAL= is an alphanumeric character.

* Fields
Each of the subtypes, =Subscript= and =Superscript= are of the form:
#+begin_src
char::Char
script::AbstractString
#+end_src
"""
abstract type Script <: OrgObject end
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

@doc org"""
*Org Syntax Reference*: \S5.11 \\
*Org Component Type*: Object

* Forms
#+begin_src org
CONTENTS SPACES|
#+end_src

- =CONTENTS= can contain any character except "|"
- =SPACES= contains any number of space characters, including zero

The final bar "|" is optional for the final cell in a row.

* Fields
#+begin_src julia
contents::AbstractString
#+end_src
"""
mutable struct TableCell <: OrgObject
    contents::AbstractString
    function TableCell(content::AbstractString)
        @parseassert(TableCell, !occursin("|", content),
                     "\"$content\" cannot contain \"|\"")
        new(strip(content))
    end
end
Base.length(cell::TableCell) = length(cell.contents)

@doc org"""
*Org Syntax Reference*: \S5.0 \\
*Org Component Type*: Object

* Forms
#+begin_src org
<%%(SEXP)>                                                    #  (diary)
<DATE TIME REPEATER-OR-DELAY>                                 #  (active)
[DATE TIME REPEATER-OR-DELAY]                                 #  (inactive)
<DATE TIME REPEATER-OR-DELAY>--<DATE TIME REPEATER-OR-DELAY>  #  (active range)
<DATE TIME-TIME REPEATER-OR-DELAY>                            #  (active range)
[DATE TIME REPEATER-OR-DELAY]--[DATE TIME REPEATER-OR-DELAY]  #  (inactive range)
[DATE TIME-TIME REPEATER-OR-DELAY]                            #  (inactive range)

#+end_src

- =DATE= is of the form "YYYY-MM-DD DAYNAME"
- =TIME= is of the form "HH:MM" or "H:MM"
- =REPEATER-OR-DELAY= is more complicated
- =SEXP= can contain any character excep ">" or "\\n"

* Fields
There are a large number of subtypes.\
TODO fill in more info
"""
abstract type Timestamp <: OrgObject end
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

@doc org"""
Represents a string which has no markup.
* Fields
#+begin_src julia
text::AbstractString
#+end_src
"""
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

@doc org"""
*Org Syntax Reference*: \S5.13 \\
*Org Component Type*: Object

* Forms
#+begin_src org
PRE MARKER BORDER BODY BORDER MARKER POST
#+end_src

- =PRE= is the beginning of a line, a whitespace character, or one of -({'"
- =POST= is the end of a line, a whitespace character, or one of -.,;:!?')}["
- =MARKER= is "*", "=", "/", "+", "_", or "~" (see =TextMarkupMarkers=)
- =BORDER= is any non-whitespace character
- =BODY= can contain any object allowed in a =Paragraph=

* Fields
#+begin_src julia
type::Symbol
marker::Char
pre::AbstractString
contents::Vector{OrgObject}
post::AbstractString
#+end_src
"""
mutable struct TextMarkup <: OrgObject
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

# For convenience
TextMarkup(marker::Char, content::AbstractString) = TextMarkup(marker, "", content, "")
Bold(content::AbstractString) = TextMarkup('*', content)
Italic(content::AbstractString) = TextMarkup('/', content)
Strikethrough(content::AbstractString) = TextMarkup('+', content)
Underline(content::AbstractString) = TextMarkup('_', content)
Code(content::AbstractString) = TextMarkup('~', content)
