# ---------------------
# Sections
# ---------------------

@doc org"""
*Org Syntax Reference*: \S1 \\
*Org Component Type*: Heading

* Form
#+begin_example
STARS KEYWORD PRIORITY TITLE TAGS
#+end_example

+ =STARS= is a string starting at column 0, containing at least one asterisk,
  and ended by a space character. This is the only manatory component of a Heading.
+ =KEYWORD= is a TODO keyword. Case is significant.
+ =PRIORITY= is a priority cookie of the form =[#P]= where =P= is a single letter
+ =TITLE= can be made of any character but a new line
+ =TAGS= is made of words containing any alphanumeric character or =_@#%=,
  seperated and enclosed by colons.

When the first word in =TITLE= is =COMMENT= (all-caps), the section will be
considered commented.

A headline may directly contain a *Section*.

* Examples
#+begin_src org
* A simple heading
** A second-level heading, with a :tag:
*** TODO [#A] Finish the Org parser :julia:org:
#+end_src

* Fields
#+begin_src julia
level::Integer
keyword::Union{AbstractString, Nothing}
priority::Union{AbstractString, Nothing}
title::AbstractString
tags::Vector{AbstractString}
section::Union{Section, Nothing}
#+end_src
""" Heading

@doc org"""
*Org Syntax Reference*: \S1 \\
*Org Component Type*: Section

* Form
A *Section* can contain any number of *Greater Elements* or *Elements*.

* Fields
#+begin_src julia
content::Vector{Union{OrgGreaterElement, OrgElement}}
#+end_src
""" Section

# ---------------------
# Greater Elements
# ---------------------

@doc org"""
*Org Syntax Reference*: \S3.1 \\
*Org Component Type*: Greater Element

* Form
#+begin_example
,#+BEGIN_NAME PARAMETERS
CONTENTS
,#+END_NAME
#+end_example

+ =NAME= can contain any non-whitespace character
+ =PARAMETERS= can contain any character other than a newline
+ =CONTENTS= can contain any element except a line =#+END_NAME=.
  Lines beginning with =*= must be quoted by a comma.

If =NAME= is =CENTER= it will be a *center block*, if it is =QUOTE=,
it will be a *quote block*.

If the block is neither a *center block*, a *quote block*, or a *block element*,
it will be a *special block*.

* Examples
#+begin_src org
TODO?
#+end_src

* Fields
#+begin_src julia
TODO
#+end_src
""" GreaterBlock

@doc org"""
*Org Syntax Reference*: \S3.2 \\
*Org Component Type*: Greater Element

* Form
#+begin_example
:NAME:
CONTENTS
:END:
#+end_example

+ =NAME= can contain word-constituent characters, hyphens and underscores.
+ =CONTENTS= can contain any element but another drawer

* Examples
#+begin_src org
TODO?
#+end_src

* Fields
#+begin_src julia
name::AbstractString
contents::Vector{OrgElement}
#+end_src
""" Drawer

@doc org"""
*Org Syntax Reference*: \S3.3 \\
*Org Component Type*: Greater Element

* Form
#+begin_example
,#+BEGIN: NAME PARAMETERS
CONTENTS
,#+END:
#+end_example

+ =NAME= cannot contain any whitespace
+ =PARAMETERS= is optional, and can contain any character except a newline

* Examples
#+begin_src org
TODO?
#+end_src

* Fields
#+begin_src julia
name::AbstractString
parameters::Union{AbstractString, Nothing}
contents::Vector{OrgElement}
#+end_src
""" DynamicBlock

@doc org"""
*Org Syntax Reference*: \S3.4 \\
*Org Component Type*: Greater Element

* Form
#+begin_example
[fn:LABEL] CONTENTS
#+end_example

+ =LABEL= is either a number, or a sequence of word-constituent charachters,
  hyphens, and underscores.
+ =CONTENTS= can contain any element but another *Footnote Definition*. It ends at:
  - The next *Footnote Definition*
  - The next *Heading*
  - Two consecutive empty lines
  - The end of the buffer

* Examples
#+begin_src org
[fn:1] a footnote
#+end_src

* Fields
#+begin_src julia
label::AbstractString
contents::Vector{OrgElement}
#+end_src
""" FootnoteDef

@doc org"""
*Org Syntax Reference*: \S3.5 \\
*Org Component Type*: Greater Element

* TODO Documentation
""" InlineTask

@doc org"""
*Org Syntax Reference*: \S3.6 \\
*Org Component Type*: Greater Element

* Form
A collection of *Items*.

* Examples
#+begin_src org
- it's
- a
- list
#+end_src

* Fields
#+begin_src julia
items::Vector{Item}
#+end_src
""" List

@doc org"""
*Org Syntax Reference*: \S3.6 \\
*Org Component Type*: Greater Element

* Form
#+begin_example
BULLET COUNTERSET CHECKBOX TAG CONTENT
#+end_example

+ =BULLET= is either a =+=, =-=, or =*= charachter or of the form
  =C)= or =C.= where =C= is a number or single alphabetical charachter.
+ =COUNTERSET= is of the form =[@C]=, for =C= as described above.
+ =CHECKBOX= is either =[ ]=, =[-]=, or =[X]=
+ =TAG= is of the form =T ::= where =T= contains any charachter but
  a newline or =::=

* Examples
#+begin_src org
+ a simple list item
- [-] a half-completed action
3. tag :: a description item
#+end_src

* Fields
#+begin_src julia
#+end_src
""" Item

@doc org"""
*Org Syntax Reference*: \S3.7 \\
*Org Component Type*: Greater Element

* Forms
A property draw can occur in two patterns:
#+begin_example
HEADLINE
PROPERTYDRAWER

HEADLINE
PLANNING
PROPERTYDRAWER
#+end_example

Where =PROPERTYDRAWER= is of the form
#+begin_example
:PROPERTIES:
CONTENTS
:END:
#+end_example

Where =CONTENTS= consistes of zero or more *Node Properties*.

* Examples
#+begin_src org
TODO?
#+end_src

* Fields
#+begin_src julia
name::AbstractString
contents::Vector{NodeProperty}
#+end_src
""" PropertyDrawer

@doc org"""
*Org Syntax Reference*: \S3.8 \\
*Org Component Type*: Greater Element

* Form

*Tables* must start with =|=, and end at the first line
which does not start with =|=. *Tables* can contain only *Table Rows*.

A *Table* may be followed by any number of =#+TBLFM: FORMULAS= lines where
=FORMULAS= can contain any charachter but a newline.

tabel.el style tables are currently not supported.

* Examples
#+begin_src org
| a simple | table   |
|----------+---------|
| some     | content |
#+end_src

* Fields
#+begin_src julia
#+end_src
""" Table

# ---------------------
# Elements
# ---------------------

@doc org"""
*Org Syntax Reference*: \S4.1 \\
*Org Component Type*: Element

* Form
#+begin_example
#+CALL: VALUE
#+end_example

+ =VALUE= is optional, it can contain any character but a newline.

* Fields
#+begin_src julia
name::AbstractString
#+end_src
""" BabelCall

@doc org"""
*Org Syntax Reference*: \S4.2 \\
*Org Component Type*: Element

* Form
#+begin_example
,#+BEGIN_NAME DATA
CONTENTS
,#+END_NAME
#+end_example

+ =NAME= can contain any whitespace character
+ =DATA= (optional) can contain any character but a newline
+ =CONTENTS= can contain any character, including newlines.
  It can only contain Org *Objects* if it is a *Verse Block*.

* Examples
#+begin_src org
TODO?
#+end_src

* Fields
#+begin_src julia
name::AbstractString
data::Union{AbstractString, Nothing}
contents::AbstractString
#+end_src
""" Block

# DiarySexp

@doc org"""
*Org Syntax Reference*: \S4.4 \\
*Org Component Type*: Element

* Form
#+begin_example
,# CONTENTS
#+end_example

+ =CONTENTS= either starts with a whitespace character, or is a newline.
  It can contain any characters.

* Examples
#+begin_src org
,#
,# hey, it's a comment
#+end_src

* Fields
#+begin_src julia
contents::AbstractString
#+end_src
""" Comment

@doc org"""
*Org Syntax Reference*: \S4.5 \\
*Org Component Type*: Element

* Form
#+begin_example
: CONTENTS
#+end_example

+ =CONTENTS= either starts with a whitespace character, or is a newline.
  It can contain any characters.

* Examples
#+begin_src org
: just some fixed
: width text
#+end_src

* Fields
#+begin_src julia
contents::AbstractString
#+end_src
""" FixedWidth

@doc org"""
*Org Syntax Reference*: \S4.6 \\
*Org Component Type*: Element

* Form

At least five consecutive hyphens, optionally indented.
""" HorizontalRule

@doc org"""
*Org Syntax Reference*: \S4.7 \\
*Org Component Type*: Element

* Form
#+begin_example
,#+KEY: VALUE
#+end_example

+ =KEY= can contain any non-whitespace characters, but cannot be =CALL= or any
  *Affiliated Keyword*.
+ =VALUE= can contain any character except a newline.

* Examples
#+begin_src org
,#+title: Document title
#+end_src

* Fields
#+begin_src julia
key::AbstractString
value::AbstractString
#+end_src
""" Keyword

@doc org"""
*Org Syntax Reference*: \S4.8 \\
*Org Component Type*: Element

* Form
#+begin_example
\begin{NAME} CONTENTS \end{NAME}
#+end_example

+ =NAME= can contain any alphanumeric character and =*=
+ =CONTENTS= can contain anything but =\end{NAME}=

* Examples
#+begin_src org
\begin{align*}
2x - 5y &= 8 \\
3x + 9y &= -12
\end{align*}
#+end_src

* Fields
#+begin_src julia
name::AbstractString
contents::AbstractString
#+end_src
""" LaTeXEnvironment

@doc org"""
*Org Syntax Reference*: \S4.9 \\
*Org Component Type*: Element

* Forms
#+begin_example
:NAME: VALUE
:NAME+: VALUE
:NAME:
:NAME+:
#+end_example

+ =NAME= can contain any non-whitespace character, but cannot end with =+=
  or be the empty string
+ =VALUE= can contain anything but the newline character

* Examples
#+begin_src org
TODO?
#+end_src

* Fields
#+begin_src julia
name::AbstractString
additive::Bool
value::AbstractString
#+end_src
""" NodeProperty

@doc org"""
*Org Syntax Reference*: \S4.10 \\
*Org Component Type*: Element

* Form

*Paragraphs* are the /default element/, and so any unrecognised content
is a paragraph.

A paragraph can contain every Org *Object*, and is ended by *Empty Lines*
and other *Elements*.

* Examples
#+begin_src org
Hey look, it's just some text.
#+end_src

* Fields
#+begin_src julia
objects::Vector{OrgObject}
#+end_src
""" Paragraph

@doc org"""
*Org Syntax Reference*: \S4.11 \\
*Org Component Type*: Element

* Forms
#+begin_example
| TABLEROW
| TABLEHRULE
#+end_example


* Examples
#+begin_src org
#+end_src

* Fields
#+begin_src julia
cells::Vector{TableCell}
#+end_src
""" TableRow

# Empty Line

# ---------------------
# Objects
# ---------------------

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
""" Entity

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
""" LaTeXFragment

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
""" ExportSnippet

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
""" FootnoteRef

@doc org"""
*Org Syntax Reference*: \S5.4 \\
*Org Component Type*: Object

* Forms
#+begin_src org
call_NAME(ARGUMENTS)
call_NAME[HEADER](ARGUMENTS)[HEADER]
#+end_src

+ =NAME= can contain any charachter besides "(", ")", and \n"
+ =ARGUMENTS= can contain any charachter besides ")" and \n"
+ =HEADER= can contain any character besides "]" and \n"

* Fields
#+begin_src julia
name::AbstractString
header::Union{AbstractString, Nothing}
arguments::Union{AbstractString, Nothing}
#+end_src
""" InlineBabelCall

@doc org"""
*Org Syntax Reference*: \S5.4 \\
*Org Component Type*: Object

* Forms
#+begin_src org
src_LANG{BODY}
src_LANG[OPTIONS]{BODY}
#+end_src

+ =LANG= can contain any non-whitespace character
+ =BODY= and =OPTIONS= can contain any character but \n"

* Fields
#+begin_src julia
lang::AbstractString
options::Union{AbstractString, Nothing}
body::AbstractString
#+end_src
""" InlineSourceBlock

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
""" LinkPath

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
""" Link

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
""" Macro

@doc org"""
*Org Syntax Reference*: \S5.8 \\
*Org Component Type*: Object

* Forms
#+begin_src org
<<<CONTENTS>>>
#+end_src

+ =CONTENTS= can be any character besides =<=, =>= and =\n=,
  but cannot start or end with whitespace.

* Fields
#+begin_src julia
contents::AbstractString
#+end_src
""" RadioTarget

@doc org"""
*Org Syntax Reference*: \S5.8 \\
*Org Component Type*: Object

* Forms
#+begin_src org
<<CONTENTS>>
#+end_src

+ =CONTENTS= can be any character besides "<", ">" and \n",
  but cannot start or end with whitespace. It cannot contain any objects.

* Fields
#+begin_src julia
contents::AbstractString
#+end_src
""" Target

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
""" StatisticsCookie

@doc org"""
See =StatisticsCookie=.
"""
StatisticsCookiePercent

@doc org"""
See =StatisticsCookie=.
"""
StatisticsCookieFraction

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
""" Script

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
""" TableCell

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
+ =SEXP= can contain any character excep ">" or \n"

* Fields
There are a large number of subtypes.\
TODO fill in more info
""" Timestamp

@doc org"""
Represents a string which has no markup.
* Fields
#+begin_src julia
text::AbstractString
#+end_src
""" TextPlain

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
""" TextMarkup

# ---------------------
# Functions / Variables
# ---------------------

@doc org"""
#+begin_src julia
orgmatcher(::Type{C}) where {C <: OrgComponent}
#+end_src

Return a /matcher/ for components of type ~C~.
This will either be:
+ a regular expression which matcher the entire component
+ a function which takes a string and returns either
  - nothing, if the string does not start with the component
  - the substring which has been identified as an instance of the component
""" matcher

@doc org"""
#+begin_src julia
consume(component::Type{<:OrgComponent}, text::AbstractString)
#+end_src
Try to /consume/ a ~component~ from the start of ~text~.

Returns a tuple of the consumed text and the resulting component
or =nothing= if this is not possible.
""" consume
