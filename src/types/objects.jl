using Dates

abstract type OrgObject <: OrgComponent end

include("../data/entities.jl")
@doc org"""
*Org Syntax Reference*: \S5.1 \\
*Org Component Type*: Object

* Form
#+begin_src org
\NAME POST
#+end_src

+ =NAME= is a key of ~Entities~.
+ =POST= may be an EOL, "{}", or a non-alphabetical character.

=NAME= and =POST= are /not/ seperated by whitespace.

* Fields
#+begin_src julia
name::AbstractString
post::AbstractString
#+end_src
"""
mutable struct Entity <: OrgObject
    name::AbstractString
    post::AbstractString
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

+ =NAME= contains alphabetical characters only
+ =BRACKETS= is optional, and not seperated from =NAME= by whitespace.
+ =CONTENTS= can contain any charachters, but not the closing delimiter
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

@doc org"""
*Org Syntax Reference*: \S5.2 \\
*Org Component Type*: Object

* Form
#+begin_src org
@@BACKEND:SNIPPET@@
#+end_src

+ =BACKEND= can contain any alphanumeric charachter, and hyphens
+ =SNIPPET= can contain anything but the "@@" string

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

@doc org"""
*Org Syntax Reference*: \S5.3 \\
*Org Component Type*: Object

* Forms
#+begin_src org
[fn:LABEL]
[fn:LABEL:DEFINITION]
[fn::DEFINITION]
#+end_src

+ =LABEL= can contain any word-constituent character, hyphens, and underscores
+ =DEFINITION= can contain any charachter, any any object encountered in a =Paragraph=
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

@doc org"""
*Org Syntax Reference*: \S5.4 \\
*Org Component Type*: Object

* Forms
#+begin_src org
call_NAME(ARGUMENTS)
call_NAME[HEADER](ARGUMENTS)[HEADER]
#+end_src

+ =NAME= can contain any charachter besides "(", ")", and "\\n"
+ =ARGUMENTS= can contain any charachter besides ")" and "\\n"
+ =HEADER= can contain any character besides "]" and "\\n"

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

@doc org"""
*Org Syntax Reference*: \S5.4 \\
*Org Component Type*: Object

* Forms
#+begin_src org
src_LANG{BODY}
src_LANG[OPTIONS]{BODY}
#+end_src

+ =LANG= can contain any non-whitespace character
+ =BODY= and =OPTIONS= can contain any character but "\\n"

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

@doc org"""
*Org Syntax Reference*: \S5.5 \\
*Org Component Type*: Object

* Forms
#+begin_src org
\\SPACE
#+end_src

+ =SPACE= can contain any number of tabs and spaces, including zero.

This pattern must occur at the end of any otherwise non-empty line.
"""
struct LineBreak <: OrgObject end

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

+ =PROTOCOL= is any recognised protocol string
+ =PATH=, =CUSTOM-ID=, =CODEREF=, and =FUZZY= can contain any character besides "[" or "]"
+ =ID= is a hexidecimal string seperated by hyphens

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

+ =LINKPATH= is descriped by =LinkPath=
+ =DESCRIPTION= can contain any character but square brackets
+ =PRE1= and =POST1= are non-alphanumeric characters
+ =PRE2= and =POST2= are non-word-constituent characters
+ =RADIO= is a string matched by some =RadioTarget=

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

@doc org"""
*Org Syntax Reference*: \S5.7 \\
*Org Component Type*: Object

* Forms
#+begin_src org
{{{NAME(ARGUMENTS)}}}
#+end_src

+ =NAME= must start with a letter can be followed by any number of
  alpha-numeric characters, hyphens and underscores.
+ =ARGUMENTS= can contain anything but “}}}” string.
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

@doc org"""
*Org Syntax Reference*: \S5.8 \\
*Org Component Type*: Object

* Forms
#+begin_src org
<<<CONTENTS>>>
#+end_src

+ =CONTENTS= can be any character besides "<", ">" and "\\n",
  but cannot start or end with whitespace.

* Fields
#+begin_src julia
contents::AbstractString
#+end_src
"""
mutable struct RadioTarget <: OrgObject
    contents::AbstractString
    # contents::Vector{Union{TextMarkup, Entity, LaTeXFragment, Subscript, Superscript}}
end

@doc org"""
*Org Syntax Reference*: \S5.8 \\
*Org Component Type*: Object

* Forms
#+begin_src org
<<CONTENTS>>
#+end_src

+ =CONTENTS= can be any character besides "<", ">" and "\\n",
  but cannot start or end with whitespace. It cannot contain any objects.

* Fields
#+begin_src julia
contents::AbstractString
#+end_src
"""
mutable struct Target <: OrgObject
    target::AbstractString
end

@doc org"""
*Org Syntax Reference*: \S5.9 \\
*Org Component Type*: Object

* Forms
#+begin_src org
[PERCENTAGE%]
[COMPLETE/TOTAL]
#+end_src

+ =PERCENTAGE=, =COMPLETE=, and =TOTAL= are numbers or an empty string.

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

@doc org"""
*Org Syntax Reference*: \S5.10 \\
*Org Component Type*: Object

* Forms
#+begin_src org
CHAR_SCRIPT
CHAR^SCRIPT
#+end_src

+ =CHAR= is any non-whitespace character
+ =SCRIPT= is either:
  - "*"
  - An expresion enclosed in curly brackets "{...}", which can itself
    contain balenced parenthesis
  - A pattern =SIGN CHARS FINAL= (without the whitespace), where
    + =SIGN= is either "+", "-", or ""
    + =CHARS= is any number of alpha-numeric characters, commas,
      backslashes and dots, or the empty string.
    + =FINAL= is an alphanumeric character.

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

@doc org"""
*Org Syntax Reference*: \S5.11 \\
*Org Component Type*: Object

* Forms
#+begin_src org
CONTENTS SPACES|
#+end_src

+ =CONTENTS= can contain any character except "|"
+ =SPACES= contains any number of space characters, including zero

The final bar "|" is optional for the final cell in a row.

* Fields
#+begin_src julia
contents::AbstractString
#+end_src
"""
mutable struct TableCell <: OrgObject
    contents::AbstractString
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

+ =DATE= is of the form "YYYY-MM-DD DAYNAME"
+ =TIME= is of the form "HH:MM" or "H:MM"
+ =REPEATER-OR-DELAY= is more complicated
+ =SEXP= can contain any character excep ">" or "\\n"

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
mutable struct TimestampInactive <: Timestamp
    date::Date
    time::Union{Time, Nothing}
    repeater::Union{TimestampRepeaterOrDelay, Nothing}
end
mutable struct TimestampActiveRange <: Timestamp
    start::TimestampActive
    stop::TimestampActive
end
mutable struct TimestampInactiveRange <: Timestamp
    start::TimestampInactive
    stop::TimestampInactive
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

@doc org"""
*Org Syntax Reference*: \S5.13 \\
*Org Component Type*: Object

* Forms
#+begin_src org
PRE MARKER BORDER BODY BORDER MARKER POST
#+end_src

+ =PRE= is the beginning of a line, a whitespace character, or one of -({'"
+ =POST= is the end of a line, a whitespace character, or one of -.,;:!?')}["
+ =MARKER= is "*", "=", "/", "+", "_", or "~" (see =TextMarkupMarkers=)
+ =BORDER= is any non-whitespace character
+ =BODY= can contain any object allowed in a =Paragraph=

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
    contents::Union{Vector{OrgObject}, AbstractString}
    post::AbstractString
end
