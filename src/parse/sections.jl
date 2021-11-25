include("greaterelements.jl") # Org Syntax §3

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
"""
mutable struct Heading <: OrgComponent
    level::Integer
    keyword::Union{AbstractString, Nothing}
    priority::Union{AbstractString, Nothing}
    title::AbstractString
    tags::Vector{AbstractString}
    section::Union{Section, Nothing}
end

@doc org"""
*Org Syntax Reference*: \S1 \\
*Org Component Type*: Heading

* Form
A *Section* can contain any number of *Greater Elements* or *Elements*.

* Fields
#+begin_src julia
content::Vector{Union{OrgGreaterElement, OrgElement}}
#+end_src
"""
mutable struct Section <: OrgComponent # Org Syntax §1
    content::Vector{Union{OrgGreaterElement, OrgElement}}
end
