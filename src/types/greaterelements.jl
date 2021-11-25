abstract type OrgGreaterElement <: OrgComponent end # Org Syntax §3
include("elements.jl") # Org Syntax §4

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
"""
mutable struct GreaterBlock <: OrgGreaterElement
end

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
"""
mutable struct Drawer <: OrgGreaterElement
    name::AbstractString
    contents::Vector{OrgElement}
end

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
"""
mutable struct DynamicBlock <: OrgGreaterElement
    name::AbstractString
    parameters::Union{AbstractString, Nothing}
    contents::Vector{OrgElement}
end

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
"""
mutable struct FootnoteDef <: OrgGreaterElement
    label::AbstractString
    contents::Vector{OrgElement}
end

@doc org"""
*Org Syntax Reference*: \S3.5 \\
*Org Component Type*: Greater Element

* TODO Documentation
"""
mutable struct InlineTask <: OrgGreaterElement
end

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
"""
abstract type List <: OrgGreaterElement end

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
"""
mutable struct Item <: OrgGreaterElement
    bullet::AbstractString
    counterset::Union{AbstractString, Nothing}
    checkbox::Union{Char, Nothing}
    tag::Union{AbstractString, Nothing}
    content::Vector{Union{OrgElement, List}}
end

mutable struct UnorderedList <: List
    items::Vector{Item}
end
mutable struct OrderedList <: List
    items::Vector{Item}
end
mutable struct DescriptiveList <: List
    items::Vector{Item}
end

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
"""
mutable struct PropertyDrawer <: OrgGreaterElement
    name::AbstractString
    contents::Vector{NodeProperty}
end

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
"""
mutable struct Table <: OrgGreaterElement
    rows::Vector{Union{TableRow, TableHrule}}
    formulas::Vector{AbstractString}
end
