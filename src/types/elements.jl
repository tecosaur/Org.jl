abstract type OrgElement <: OrgComponent end # Org Syntax §4
include("objects.jl") # Org Syntax §5

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
"""

mutable struct BabelCall <: OrgElement # Org Syntax §4.1
    name::AbstractString
end

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
"""
mutable struct Block <: OrgElement
    name::AbstractString
    data::Union{AbstractString, Nothing}
    contents::AbstractString
end
# TODO 1st class src block, convert Block to a abstract type and subtype it?

mutable struct DiarySexp <: OrgElement end # Org Syntax §4.3

mutable struct Planning <: OrgElement end # Org Syntax §4.3

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
"""

mutable struct Comment <: OrgElement
    contents::AbstractString
end

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
"""

mutable struct FixedWidth <: OrgElement
    contents::AbstractString
end

@doc org"""
*Org Syntax Reference*: \S4.6 \\
*Org Component Type*: Element

* Form

At least five consecutive hyphens, optionally indented.
"""
struct HorizontalRule <: OrgElement end

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
"""
mutable struct Keyword <: OrgElement
    key::AbstractString
    value::AbstractString
end

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
"""
mutable struct LaTeXEnvironment <: OrgElement
    name::AbstractString
    contents::AbstractString
end

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
"""
mutable struct NodeProperty <: OrgElement
    name::AbstractString
    additive::Bool
    value::AbstractString
end

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
"""
mutable struct Paragraph <: OrgElement
    objects::Vector{OrgObject}
end

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
"""
mutable struct TableRow <: OrgElement
    cells::Vector{TableCell}
end
struct TableHrule <: OrgElement end

struct EmptyLine <: OrgElement end
