# Thanks to load order issues, we have to do the documentation seperately

Base.Docs.catdoc(org::Org...) = *(org...)

@doc org"""
A type representing an Org document.

#+begin_src julia
Org([settings::Dict], contents::Vector{Union{Heading, Section}})
#+end_src

There are three ways of constructing an Org document:
1. Calling the `Org` constructor with a vector of Headings/Sections
2. Calling ~parse(Org, content::String)~
3. The ~org""~ macro

* Org Documents

Org is a plaintext format composed of simple, yet versatile, forms which
represent formatting and structural information. It is designed to be both
intuitive to use, and capable of representing complex documents.

* Objects and Elements

The components of an Org document can be divided into two classes: "objects" and
"elements". /Elements/ are syntactic components that exist at the same or greater
scope than a paragraph, i.e. which could not be contained by a paragraph.
Conversely, /objects/ are syntactic components that exist with a smaller scope
than a paragraph, and so can be contained within a paragraph.

See the docs for the *Greater Element*, *Lesser Element*, and *Object* types for
more information.

* Fields

#+begin_src julia
settings::Dict
contents::Vector{Union{Heading, Section}}
cache::OrgCache
#+end_src
""" Org

# ---------------------
# Elements, Sectioning
# ---------------------

@doc org"""
An abstract type for the various typef of elements, namely:
+ Headings and Sections
+ Greater Elements
+ Lesser Elements
""" Element

@doc org"""
*Org Syntax Reference*: \S3.1.1 \\
*Org Component Type*: Element

* Form

#+begin_example
STARS KEYWORD PRIORITY TITLE TAGS
#+end_example

+ STARS :: A string consisting of one or more asterisks (up to
  ~org-inlinetask-min-level~ if the =org-inlinetask= library is loaded)
  and ended by a space character.  The number of asterisks is used to
  define the level of the heading.

+ KEYWORD (optional) :: A string which is a member of
  ~org-todo-keywords-1~[fn:otkw1:By default, ~org-todo-keywords-1~ only
  contains =TODO= and =DONE=, however this is liable to change.].  Case is
  significant.  This is called a "TODO keyword".

+ PRIORITY (optional) :: A single alphanumeric character preceded by a
  hash sign =#= and enclosed within square brackets (e.g. =[#A]= or =[#1]=).  This
  is called a "priority cookie".

+ TITLE (optional) :: A series of objects from the standard set,
  excluding line break objects.  It is matched after every other part.

+ TAGS (optional) :: A series of colon-separated strings consisting of
  alpha-numeric characters, underscores, at signs, hash signs, and
  percent signs (=_@#%=).

If the first word appearing in the title is =COMMENT=, the heading
will be considered as "commented".  Case is significant.

If its title is the value of ~org-footnote-section~ (=Footnotes= by
default), it will be considered as a "footnote section".  Case is
significant.

If =ARCHIVE= is one of the tags given, the heading will be considered as
"archived".  Case is significant.

All content following a heading --- up to either the next heading, or the end of
the document, forms a section contained by the heading. This is optional, as the
next heading may occur immediately in which case no section is formed.

* Examples

#+begin_src org
,* A simple heading
,** A second-level heading, with a :tag:
,*** TODO [#A] Finish the Org parser :julia:org:
#+end_src

* Fields

#+begin_src julia
level::Integer
keyword::Union{AbstractString, Nothing}
priority::Union{AbstractString, Nothing}
title::Vector{Object}
tags::Vector{AbstractString}
section::Union{Section, Nothing}
planning::Union{Planning, Nothing}
properties::Union{PropertyDrawer, Nothing}
#+end_src
""" Heading

@doc org"""
*Org Syntax Reference*: \S3.1.2 \\
*Org Component Type*: Element

* Form

Sections contain one or more non-*heading* elements.
With the exception of the text before the first heading in a document (which is
considered a section), sections only occur within headings.

* The top level section

All elements before the first heading in a document lie in a special
section called the /top level section/.  It may be preceded by blank
lines.  Unlike a normal section, the top level section can immediately
contain a *property drawer*, optionally preceded by *comments*.  It cannot
however, contain *planning*.

* Fields

#+begin_src julia
content::Vector{Element}
#+end_src
""" Section

@doc org"""
*Org Syntax Reference*: \S3.2 \\
*Org Component Type*: Element

With the exception of *comments*, *clocks*, *headings*, *inlinetasks*,
*items*, *node properties*, *planning*, *property drawers*, *sections*, and
*table rows*, every other element type can be assigned attributes.

This is done by adding specific *keywords*, named /affiliated/ keywords,
immediately above the element considered (a blank line cannot lie
between the affiliated keyword and element). Structurally, affiliated
keyword are not considered an element in their own right but a
property of the element they apply to.

* Form

#+begin_example
,#+KEY: VALUE
,#+KEY[OPTVAL]: VALUE
,#+attr_BACKEND: VALUE
#+end_example

+ KEY :: A string which is a member of
  ~org-element-affiliated-keywords~[fn:oeakw:By default,
  ~org-element-affiliated-keywords~ contains =CAPTION=, =DATA=, =HEADERS=,
  =LABEL=, =NAME=, =PLOT=, =RESNAME=, =RESULT=, =RESULTS=, =SOURCE=, =SRCNAME=, and
  =TBLNAME=.].
+ BACKEND :: A string consisting of alphanumeric characters, hyphens,
  or underscores (=-_=).
+ OPTVAL (optional) :: A string consisting of any characters but a
  newline.  Opening and closing square brackets must be balanced.
  This term is only valid when KEY is a member of
  ~org-element-dual-keywords~[fn:oedkw:By default,
  ~org-element-dual-keywords~ contains =CAPTION= and =RESULTS=.].
+ VALUE :: A string consisting of any characters but a newline, except
  in the case where KEY is member of
  ~org-element-parsed-keywords~[fn:oepkw:By default,
  ~org-element-parsed-keywords~ contains =CAPTION=.] in which case VALUE
  is a series of objects from the standard set, excluding footnote
  references.

Repeating an affiliated keyword before an element will usually result
in the prior VALUEs being overwritten by the last instance of KEY.
There are two situations under which the VALUEs will be concatenated:
1. If KEY is a member of ~org-element-dual-keywords~[fn:oedkw].
2. If the affiliated keyword is an instance of the patten
   =#+attr_BACKEND: VALUE=.

* Example

The following example contains three affiliated keywords:

#+begin_example
,#+name: image-name
,#+caption: This is a caption for
,#+caption: the image linked below
[[file:some/image.png]]
#+end_example

* Fields

#+begin_src julia
key::AbstractString
optval::Union{<:AbstractString, Vector{Object}, Nothing}
value::Union{<:AbstractString, Vector{Object}, Nothing}
#+end_src
""" AffiliatedKeyword

@doc org"""
A wrapper for a collection of *affiliated keywords* and an *element*.

See the docstring for ~AffiliatedKeyword~ for more
information of affiliated keywords.

* Fields

#+begin_src julia
element::Element
keywords::Vector{AffiliatedKeyword}
#+end_src
""" AffiliatedKeywordsWrapper

# ---------------------
# Greater Elements
# ---------------------

@doc org"""
*Org Syntax Reference*: \S3.3

Unless specified otherwise, greater elements can contain directly
any greater or *lesser element* except:
+ Elements of their own type.
+ *Planning*, which may only occur in a *heading*.
+ *Property drawers*, which may only occur in a *heading* or the *top level
  section*.
+ *Node properties*, which can only be found in *property drawers*.
+ *Items*, which may only occur in *plain lists*.
+ *Table rows*, which may only occur in *tables*.
""" GreaterElement

@doc org"""
*Org Syntax Reference*: \S3.3.1 \\
*Org Component Type*: Element/Greater Element

* Form

#+begin_example
,#+begin_NAME PARAMETERS
CONTENTS
,#+end_NAME
#+end_example

+ NAME :: A string consisting of any non-whitespace characters, which
  is not the NAME of a *lesser block*.  Greater blocks are treated
  differently based on their subtype, which is determined by the NAME
  as follows:
  - =center=, a "center block"
  - =quote=, a "quote block"
  - any other value, a "special block"
+ PARAMETERS (optional) :: A string consisting of any characters other
  than a newline.
+ CONTENTS :: A collection of zero or more elements, subject to two
  conditions:
  - No line may start with =#+end_NAME=.
  - Lines beginning with an asterisk must be quoted by a comma (=,*=).
  Furthermore, lines starting with =#+= may be quoted by a comma (=,#+=).

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
*Org Syntax Reference*: \S3.3.2 \\
*Org Component Type*: Element/Greater Element

* Form

#+begin_example
:NAME:
CONTENTS
:end:
#+end_example

+ NAME :: A string consisting of word-constituent characters, hyphens
  and underscores (=-_=).
+ CONTENTS :: A collection of zero or more elements, except another drawer.

* Examples

#+begin_src org
TODO?
#+end_src

* Fields

#+begin_src julia
name::AbstractString
contents::Vector{Element}
#+end_src
""" Drawer

@doc org"""
*Org Syntax Reference*: \S3.3.3 \\
*Org Component Type*: Element/Greater Element

* Form

Dynamic blocks are structured according to the following pattern:
#+begin_example
,#+begin: NAME PARAMETERS
CONTENTS
,#+end:
#+end_example

+ NAME :: A string consisting of non-whitespace characters.
+ PARAMETERS (optional) :: A string consisting of any characters but a newline.
+ CONTENTS :: A collection of zero or more elements, except another
  dynamic block.

* Examples

#+begin_src org
TODO?
#+end_src

* Fields

#+begin_src julia
name::AbstractString
parameters::Union{AbstractString, Nothing}
contents::Vector{Element}
#+end_src
""" DynamicBlock

@doc org"""
*Org Syntax Reference*: \S3.3.4 \\
*Org Component Type*: Element/Greater Element

* Form

Footnote definitions must occur at the start of an /unindented/ line,
and are structured according to the following pattern:
#+begin_example
[fn:LABEL] CONTENTS
#+end_example

+ LABEL :: Either a number or an instance of the pattern =fn:WORD=, where
  =WORD= represents a string consisting of word-constituent characters,
  hyphens and underscores (=-_=).

+ CONTENTS (optional) :: A collection of zero or more elements.  It
  ends at the next footnote definition, the next heading, two
  consecutive blank lines, or the end of buffer.

* Examples

#+begin_example
[fn:1] A short footnote.

[fn:2] This is a longer footnote.

It even contains a single blank line.
#+end_example

* Fields
#+begin_src julia
label::AbstractString
definition::Vector{Element}
#+end_src
""" FootnoteDefinition

@doc org"""
*Org Syntax Reference*: \S3.3.5 \\
*Org Component Type*: Element/Greater Element

* Form

Inlinetasks are syntactically a *heading* with a level of at least
~org-inlinetask-min-level~[fn:oiml:The default value of
~org-inlinetask-min-level~ is =15=.], i.e. starting with at least that
many asterisks.

Optionally, inlinetasks can be ended with a second heading with a
level of at least ~org-inlinetask-min-level~[fn:oiml], with no optional
components (i.e. only STARS and TITLE provided) and the string =END= as
the TITLE. This allows the inlinetask to contain elements.

* Examples

#+begin_example
,*************** TODO some tiny task
This is a paragraph, it lies outside the inlinetask above.
,*************** TODO some small task
                 DEADLINE: <2009-03-30 Mon>
                 :PROPERTIES:
                   :SOMETHING: or other
                 :END:
                 And here is some extra text
,*************** END
#+end_example

* Fields

#+begin_src org
TODO?
#+end_src
""" InlineTask

@doc org"""
*Org Syntax Reference*: \S3.3.6 \\
*Org Component Type*: Element/Greater Element

* Form

#+begin_example
BULLET COUNTER-SET CHECK-BOX TAG CONTENTS
#+end_example

+ BULLET :: One of the two forms below, followed by either a
  whitespace character or line ending.
  - An asterisk, hyphen, or plus sign character (i.e., =*=, =-=, or =+=).
  - Either the pattern =COUNTER.= or =COUNTER)=.
    + COUNTER :: Either a number or a single letter (a-z).
+ COUNTER-SET (optional) :: An instance of the pattern =[@COUNTER]=.
+ CHECK-BOX (optional) :: A single whitespace character, an =X=
  character, or a hyphen enclosed by square brackets (i.e. =[ ]=, =[X]=, or =[-]=).
+ TAG (optional) :: An instance of the pattern =TAG-TEXT ::= where
  =TAG-TEXT= represents a string consisting of non-newline characters
  that does not contain the substring "\nbsp{}::\nbsp{}" (two colons surrounded by
  whitespace).
+ CONTENTS (optional) :: A collection of zero or more elements, ending
  at the first instance of one of the following:
  - The next item.
  - The first line less or equally indented than the starting line,
    not counting lines within other elements or *inlinetask* boundaries.
  - Two consecutive blank lines.

* Examples
#+begin_src org
- item
3. [@3] set to three
+ [-] tag :: item contents
#+end_src

* Fields
#+begin_src julia
bullet::AbstractString
counterset::Union{AbstractString, Nothing}
checkbox::Union{Char, Nothing}
tag::Union{AbstractString, Nothing}
contents::Vector{OrgComponent}
#+end_src
""" Item

@doc org"""
*Org Syntax Reference*: \S3.3.7 \\
*Org Component Type*: Element/Greater Element

* Form

A /plain list/ is a set of consecutive *items* of the same indentation.

If first item in a plain list has a COUNTER in its BULLET, the plain
list will be an "ordered plain-list".  If it contains a TAG, it will
be a "descriptive list".  Otherwise, it will be an "unordered list".
List types are mutually exclusive.

For example, consider the following excerpt of an Org document:

#+begin_example
1. item 1
2. [X] item 2
   - some tag :: item 2.1
#+end_example

Its internal structure is as follows:

#+begin_example
(ordered-plain-list
 (item)
 (item
  (descriptive-plain-list
   (item))))
#+end_example

* Fields
#+begin_src org
items::Vector{Item}
#+end_src
""" List

@doc org"""
*Org Syntax Reference*: \S3.3.8 \\
*Org Component Type*: Element/Greater Element

Property drawers are a special type of *drawer* containing properties
attached to a *heading* or *inlinetask*.  They are located right after a heading
and its *planning* information, as shown below:

#+begin_example
HEADLINE
PROPERTYDRAWER

HEADLINE
PLANNING
PROPERTYDRAWER
#+end_example

* Forms

#+begin_example
:properties:
CONTENTS
:end:
#+end_example

+ CONTENTS :: A collection of zero or more *node properties*, not
  separated by blank lines.

* Example

#+begin_src org
:PROPERTIES:
:CUSTOM_ID: someid
:END:
#+end_src

* Fields
#+begin_src julia
contents::Vector{NodeProperty}
#+end_src
""" PropertyDrawer

@doc org"""
*Org Syntax Reference*: \S3.3.9 \\
*Org Component Type*: Element/Greater Element

* Form

Tables are started by a line beginning with either:
+ A vertical bar (=|=), forming an "org" type table.
+ The string =+-= followed by a sequence of plus (=+=) and minus (=-=)
  signs, forming a "table.el" type table.

Tables cannot be immediately preceded by such lines, as the current
line would the be part of the earlier table.

Org tables contain table rows, and end at the first line not starting
with a vertical bar. An Org table can be followed by a number of
=#+TBLFM: FORMULAS= lines, where =FORMULAS= represents a string consisting
of any characters but a newline.

Table.el tables end at the first line not starting with either
a vertical line or a plus sign.

*Note*
table.el style tables are currently not supported.

* Examples
#+begin_src org
| Name  | Phone | Age |
|-------+-------+-----|
| Peter |  1234 |  24 |
| Anna  |  4321 |  25 |
#+end_src

* Fields
#+begin_src julia
rows::Vector{Union{TableRow, TableHrule}}
formulas::Vector{AbstractString}
#+end_src
""" Table

# ---------------------
# Lesser Elements
# ---------------------

@doc org"""
*Org Syntax Reference*: \S3.4

Lesser elements cannot contain any other element.

Only *keywords* which are a member of ~org-element-parsed-keywords~[fn:oepkw], *verse
blocks*, *paragraphs* or *table rows* can contain objects.
""" LesserElement

@doc org"""
*Org Syntax Reference*: \S3.4.1 \\
*Org Component Type*: Element/Lesser Element

* Form

#+begin_example
,#+call: NAME(ARGUMENTS)
,#+call: NAME[HEADER1](ARGUMENTS)
,#+call: NAME(ARGUMENTS)[HEADER2]
,#+call: NAME[HEADER1](ARGUMENTS)[HEADER2]
#+end_example

+ NAME :: A string consisting of any non-newline characters except for
  square brackets, or parentheses (=[]()=).
+ ARGUMENTS (optional) :: A string consisting of any non-newline
  characters.  Opening and closing parenthesis must be balanced.
+ HEADER1 (optional), HEADER2 (optional) :: A string consisting of any
  non-newline characters.  Opening and closing square brackets must be
  balanced.

*Note*
Only NAME is currently implemented.

* Fields

#+begin_src julia
name::AbstractString
#+end_src
""" BabelCall

@doc org"""
*Org Syntax Reference*: \S3.4.2 \\
*Org Component Type*: Element/Lesser Element

* Form

#+begin_example
,#+begin_NAME DATA
CONTENTS
,#+end_NAME
#+end_example

+ NAME :: A string consisting of any non-whitespace characters.  The
  type of the block is determined based on the value as follows:
  - =comment=, a "comment block",
  - =example=, an "example block",
  - =export=, an "export block",
  - =src=, a "source block",
  - =verse=, a "verse block".
    The NAME must be one of these values.  Otherwise, the pattern
    forms a greater block.
+ DATA (optional) :: A string consisting of any characters but a newline.
  - In the case of an export block, this is mandatory and must be a
    single word.
  - In the case of a source block, this is mandatory and must follow
    the pattern =LANGUAGE SWITCHES ARGUMENTS= with:
    + LANGUAGE :: A string consisting of any non-whitespace characters
    + SWITCHES :: Any number of SWITCH patterns, separated by a single
      space character
      - SWITCH :: Either the pattern =-l "FORMAT"= where =FORMAT=
        represents a string consisting of any characters but a double
        quote (="=) or newline, or the pattern =-S= or =+S= where =S=
        represents a single alphabetic character
    + ARGUMENTS :: A string consisting of any character but a newline.
+ CONTENTS (optional) :: A string consisting of any characters
  (including newlines) subject to the same two conditions of greater
  block's CONTENTS, i.e.
  - No line may start with =#+end_NAME=.
  - Lines beginning with an asterisk must be quoted by a comma (=,*=).
  As with greater blocks, lines starting with =#+= may be quoted by a
  comma (=,#+=).
  CONTENTS will contain Org objects when the block is a verse block,
  it is otherwise not parsed.

* Examples

#+begin_src org
,#+begin_verse
    There was an old man of the Cape
   Who made himself garments of crepe.
       When asked, “Do they tear?”
      He replied, “Here and there,
 But they’re perfectly splendid for shape!”
,#+end_verse
#+end_src

* Fields

#+begin_src julia
name::AbstractString
data::Union{AbstractString, Nothing}
contents::AbstractString
#+end_src
""" Block

# Clock

# DiarySexp

@doc org"""
*Org Syntax Reference*: \S3.4.5 \\
*Org Component Type*: Element/Lesser Element

* Form

#+begin_example
HEADING
PLANNING
#+end_example

+ HEADING :: A *heading* element.
+ PLANNING :: A line consisting of a series of =KEYWORD: TIMESTAMP=
  patterns (termed "info" patterns).
  - KEYWORD :: Either the string =DEADLINE=, =SCHEDULED=, or =CLOSED=.
  - TIMESTAMP :: A *timestamp* object.

It is not permitted for any blank lines to lie between HEADING and
PLANNING.

* Fields

#+begin_src julia
deadline::Union{Timestamp, Nothing}
scheduled::Union{Timestamp, Nothing}
closed::Union{Timestamp, Nothing}
#+end_src
""" Planning

@doc org"""
*Org Syntax Reference*: \S3.4.6 \\
*Org Component Type*: Element/Lesser Element

* Form

A "comment line" starts with a hash character (=#=) and either a whitespace
character or the immediate end of the line.

Comments consist of one or more consecutive comment lines.

* Examples

#+begin_src org
# Just a comment
#
# Over multiple lines
#+end_src

* Fields

#+begin_src julia
contents::AbstractString
#+end_src
""" Comment

@doc org"""
*Org Syntax Reference*: \S3.4.7 \\
*Org Component Type*: Element/Lesser Element

* Form

A "fixed-width line" starts with a colon character (=:=) and either a whitespace
character or the immediate end of the line.

Fixed-width areas consist of one or more consecutive fixed-width lines.

* Examples

#+begin_src org
: This is a
: fixed width area
#+end_src

* Fields

#+begin_src julia
contents::AbstractString
#+end_src
""" FixedWidth

@doc org"""
*Org Syntax Reference*: \S3.4.8 \\
*Org Component Type*: Element/Lesser Element

* Form

A horizontal rule is formed by a line consisting of at least five
consecutive hyphens (=-----=).
""" HorizontalRule

@doc org"""
*Org Syntax Reference*: \S3.4.9 \\
*Org Component Type*: Element/Lesser Element

* Form

#+begin_example
,#+KEY: VALUE
#+end_example

+ KEY :: A string consisting of any non-whitespace characters, other
  than =call= (which would forms a *babel call* element).
+ VALUE :: A string consisting of any characters but a newline.

When KEY is a member of ~org-element-parsed-keywords~[fn:oepkw], VALUE can contain
the standard set objects, excluding footnote references.

Note that while instances of this pattern are preferentially parsed as
*affiliated keywords*, a keyword with the same KEY as an affiliated
keyword may occur so long as it is not immediately preceding a valid
element that can be affiliated.  For example, an instance of
=#+caption: hi= followed by a blank line will be parsed as a keyword,
not an affiliated keyword.

* Examples

#+begin_src org
,#+title: Document title
#+end_src

* Fields

#+begin_src julia
key::AbstractString
value::Union{<:AbstractString, Vector{Object}, Nothing}
#+end_src
""" Keyword

@doc org"""
*Org Syntax Reference*: \S3.4.10 \\
*Org Component Type*: Element/Lesser Element

* Form

#+begin_example
\begin{NAME}
CONTENTS
\end{NAME}
#+end_example

+ NAME :: A string consisting of alphanumeric or asterisk characters
+ CONTENTS (optional) :: A string which does not contain the substring
  =\end{NAME}=.

* Examples

#+begin_example
\begin{align*}
2x - 5y &= 8 \\
3x + 9y &= -12
\end{align*}
#+end_example

* Fields

#+begin_src julia
name::AbstractString
contents::AbstractString
#+end_src
""" LaTeXEnvironment

@doc org"""
*Org Syntax Reference*: \S3.4.11 \\
*Org Component Type*: Element/Lesser Element

* Forms
#+begin_example
:NAME: VALUE
:NAME:
:NAME+: VALUE
:NAME+:
#+end_example

+ NAME :: A non-empty string containing any non-whitespace characters
  which does not end in a plus characters (=+=).
+ VALUE (optional) :: A string containing any characters but a newline.

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
*Org Syntax Reference*: \S3.4.12 \\
*Org Component Type*: Element/Lesser Element

* Form

Paragraphs are the default element, which means that any
unrecognized context is a paragraph.

Empty lines and other elements end paragraphs.

Paragraphs can contain the standard set of objects.

* Examples
#+begin_src org
Hey look, it's just some text.
#+end_src

* Fields
#+begin_src julia
objects::Vector{Object}
#+end_src
""" Paragraph

@doc org"""
*Org Syntax Reference*: \S3.4.13 \\
*Org Component Type*: Element/Lesser Element

* Forms

A table row consists of a vertical bar (=|=) followed by:
+ Any number of *table cells*, forming a "standard" type row.
+ A hyphen (=-=), forming a "rule" type row.  Any non-newline characters
  can follow the hyphen and this will still be a "rule" type row

Table rows can only exist in *tables*.

* Fields
#+begin_src julia
cells::Vector{TableCell}
#+end_src
""" TableRow

# ---------------------
# Objects
# ---------------------

@doc org"""
Objects can only be found in the following elements:

- *keywords* or *affiliated keywords* VALUEs, when KEY is a member of
  ~org-element-parsed-keywords~[fn:oepkw],
- *heading* TITLEs,
- *inlinetask* TITLEs,
- *item* TAGs,
- *clock* INACTIVE-TIMESTAMP and INACTIVE-TIMESTAMP-RANGE, which can
  only contain inactive timestamps,
- *planning* TIMESTAMPs, which can only be timestamps,
- *paragraphs*,
- *table cells*,
- *table rows*, which can only contain table cell objects,
- *verse blocks*.

Most objects cannot contain objects.  Those which can will be
specified.  Furthermore, while many objects may contain newlines, a
blank line often terminates the element that the object is a part of,
such as a paragraph.
""" Object

@doc org"""
*Org Syntax Reference*: \S4.1 \\
*Org Component Type*: Object

* Form

#+begin_example
\NAME POST
#+end_example

Where NAME and POST are not separated by a whitespace character.

+ NAME :: A string with a valid association in either
  ~OrgMode.Entities~ or ~org-entities-user~.
+ POST :: Either:
  - The end of line.
  - The string ={}=.
  - A non-alphabetic character.

* Examples
#+begin_example
\cent
#+end_example

* Fields

#+begin_src julia
name::AbstractString
#+end_src
""" Entity

@doc org"""
*Org Syntax Reference*: \S4.2 \\
*Org Component Type*: Object

* Forms

#+begin_example
\NAME BRACKETS
\(CONTENTS\)
\[CONTENTS\]
#+end_example

+ NAME :: A string consisting of alphabetic characters which does not
  have an association in either ~org-entities~ or ~org-entities-user~.
+ BRACKETS (optional) :: An instance of one of the following patterns,
  not separated from NAME by whitespace.
  #+begin_example
[CONTENTS1]
{CONTENTS1}
  #+end_example
  - CONTENTS1 :: A string consisting of any characters but ={=, =}=, =[=,
    =]=, or a newline.
  - CONTENTS2 :: A string consisting of any characters but ={=, =}=, or a newline.
+ CONTENTS :: A string consisting of any characters, so long as it does
  not contain the substring =\)= in the case of the
  second template, or =\]= in the case of the third template.

Org also supports TeX-style inline LaTeX fragments, but I don't like them.

* Examples

#+begin_example
\enlargethispage{2\baselineskip}
\(e^{i \pi}\)
#+end_example

* Fields

#+begin_src julia
contents::AbstractString
delimiters::Union{Tuple{AbstractString, AbstractString}, Nothing}
#+end_src
""" LaTeXFragment

@doc org"""
*Org Syntax Reference*: \S4.3 \\
*Org Component Type*: Object

* Form

#+begin_example
@@BACKEND:VALUE@@
#+end_example

+ BACKEND :: A string consisting of alphanumeric characters and hyphens.
+ VALUE (optional) :: A string containing anything but the string =@@=.

* Fields
#+begin_src julia
backend::AbstractString
snippet::AbstractString
#+end_src
""" ExportSnippet

@doc org"""
*Org Syntax Reference*: \S4.4 \\
*Org Component Type*: Object

* Forms

#+begin_example
[fn:LABEL]
[fn:LABEL:DEFINITION]
[fn::DEFINITION]
#+end_example

+ LABEL :: A string containing one or more word constituent characters,
  hyphens and underscores (=-_=).
+ DEFINITION (optional) :: A series of objects from the standard set,
  so long as opening and closing square brackets are balanced within
  DEFINITION.

If the reference follows the second pattern, it is called an "inline
footnote".  If it follows the third pattern, i.e. if LABEL is omitted,
it is called an "anonymous footnote".

Note that the first pattern may not occur on an /unindented/ line, as it
is then a *footnote definition*.

* Fields

#+begin_src julia
label::Union{AbstractString, Nothing}
definition::Union{Vector{Object}, Nothing}
#+end_src
""" FootnoteReference

@doc org"""
*Org Syntax Reference*: \S4.6 \\
*Org Component Type*: Object

* Forms

#+begin_example
KEYPREFIX @KEY KEYSUFFIX
#+end_example
Where KEYPREFIX, @​KEY, and KEYSUFFIX are not separated by whitespace.

+ KEYPREFIX (optional) :: A series of objects from the minimal set,
  so long as all square brackets are balanced within KEYPREFIX, and
  it does not contain any semicolons (=;=) or subsequence that matches
  =@KEY=.
+ KEY :: A string made of any word-constituent character, =-=, =.=, =:=,
  =?=, =!=, =`=, ='=, =/=, =*=, =@=, =+=, =|=, =(=, =)=, ={=, =}=, =<=, =>=, =&=, =_=, =^=, =$=, =#=, =%=, or
  =~=.
+ KEYSUFFIX (optional) :: A series of objects from the minimal set,
  so long as all square brackets are balanced within KEYPREFIX, and
  it does not contain any semicolons (=;=).

* Fields

#+begin_src julia
prefix::Vector{Object}
key::AbstractString
suffix::Vector{Object}
#+end_src
""" CitationReference

@doc org"""
*Org Syntax Reference*: \S4.5 \\
*Org Component Type*: Object

* Forms

#+begin_example
[cite CITESTYLE: GLOBALPREFIX REFERENCES GLOBALSUFFIX]
#+end_example

Where "cite" and =CITESTYLE=, =KEYCITES= and =GLOBALSUFFIX= are /not/
separated by whitespace.  =KEYCITES=, =GLOBALPREFIX=, and =GLOBALSUFFIX=
must be separated by semicolons.  Whitespace after the leading colon
or before the closing square bracket is not significant.  All other
whitespace is significant.

+ CITESTYLE (optional) :: An instance of either the pattern =/STYLE= or =/STYLE/VARIANT=
  - STYLE :: A string made of any alphanumeric character, =_=, or =-=.
  - Variant :: A string made of any alphanumeric character, =_=, =-=, or =/=.
+ GLOBALPREFIX (optional) :: A series of objects from the standard set,
  so long as all square brackets are balanced within GLOBALPREFIX, and
  it does not contain any semicolons (=;=) or subsequence that matches
  =@KEY=.
+ REFERENCES :: One or more *citation reference* objects, separated by
  semicolons (=;=).
+ GLOBALSUFFIX (optional) :: A series of objects from the standard set,
  so long as all square brackets are balanced within GLOBALSUFFIX, and
  it does not contain any semicolons (=;=) or subsequence that matches
  =@KEY=.

* Examples

#+begin_example
[cite:@key]
[cite/t:see;@foo p. 7;@bar pp. 4;by foo]
[cite/a/f:c.f.;the very important @@atkey @ once;the crucial @baz vol. 3]
#+end_example

* Fields

#+begin_src julia
style::Tuple{Union{AbstractString, Nothing},
              Union{AbstractString, Nothing}}
globalprefix::Vector{Object}
citerefs::Vector{CitationReference}
globalsuffix::Vector{Object}
#+end_src
""" Citation

@doc org"""
*Org Syntax Reference*: \S4.7 \\
*Org Component Type*: Object

* Forms

#+begin_example
call_NAME(ARGUMENTS)
call_NAME[HEADER1](ARGUMENTS)
call_NAME(ARGUMENTS)[HEADER2]
call_NAME[HEADER1](ARGUMENTS)[HEADER2]
#+end_example

+ NAME :: A string consisting of any non-whitespace characters except
  for square brackets or parentheses (=[](​)=).
+ ARGUMENTS (optional), HEADER1 (optional), HEADER2 (optional) :: A
  string consisting of any characters but a newline.  Opening and
  closing square brackets must be balanced.

* Fields
#+begin_src julia
name::AbstractString
header::Union{AbstractString, Nothing}
arguments::Union{AbstractString, Nothing}
#+end_src
""" InlineBabelCall

@doc org"""
*Org Syntax Reference*: \S4.8 \\
*Org Component Type*: Object

* Forms

#+begin_example
src_LANG{BODY}
src_LANG[HEADERS]{BODY}
#+end_example

+ LANG :: A string consisting of any non-whitespace characters.
+ HEADERS (optional), BODY (optional) :: A string consisting of any
  characters but a newline.  Opening and closing square brackets must
  be balanced.

* Fields

#+begin_src julia
lang::AbstractString
options::Union{AbstractString, Nothing}
body::AbstractString
#+end_src
""" InlineSourceBlock

@doc org"""
*Org Syntax Reference*: \S4.9 \\
*Org Component Type*: Object

* Forms
#+begin_example
\\SPACE
#+end_example

+ SPACE :: Zero or more tab and space characters.

This pattern must occur at the end of any otherwise non-empty line.
""" LineBreak

@doc org"""
*Org Syntax Reference*: \S4.10 \\
*Org Component Type*: Object

Links come in four subtypes:
+ ~RadioLink~
+ ~PlainLink~
+ ~AngleLink~
+ ~RegularLink~

Each of those have dedicated docstrings.
""" Link

@doc org"""
*Org Syntax Reference*: \S4.10.1 \\
*Org Component Type*: Object

* Form

#+begin_example
PRE RADIO POST
#+end_example

+ PRE :: A non-alphanumeric character.
+ RADIO :: A series of objects matched by some *radio target*.  It can
  contain the minimal set of objects.
+ POST :: A non-alphanumeric character.

* Example

#+begin_example
This is some <<<*important* information>>> which we refer to lots.
Make sure you remember the *important* information.
#+end_example

The first instance of =*important* information= defines a radio target,
which is matched by the second instance of =*important* information=,
forming a radio link.

* Fields

#+begin_src julia
radio::RadioTarget
#+end_src
""" RadioLink

@doc org"""
*Org Syntax Reference*: \S4.10.4 \\
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
*Org Syntax Reference*: \S4.10.2 \\
*Org Component Type*: Object

* Form

#+begin_example
PRE PROTOCOL:PATHPLAIN POST
#+end_example

+ PRE :: A non word constituent character.
+ PROTOCOL :: A string which is one of the link type strings in
  ~org-link-parameters~[fn:olp:By default, ~org-link-parameters~ defines
  links of type =file+sys=, =file+emacs=, =shell=, =news=, =mailto=, =https=,
  =http=, =ftp=, =help=, =file=, and =elisp=.].
+ PATHPLAIN :: A string containing any non-whitespace character but =(=, =)=,
  =<=, or =>=.  It must end with a word-constituent character, or any
  non-whitespace non-punctuation character followed by =/=.
+ POST :: A non word constituent character.

* Example

#+begin_example
Be sure to look at https://orgmode.org.
#+end_example

* Fields

#+begin_src julia
path::LinkPath
#+end_src
""" PlainLink

@doc org"""
*Org Syntax Reference*: \S4.10.3 \\
*Org Component Type*: Object

Angle-type essentially provide a method to disambiguate plain links
from surrounding text.

* Form

#+begin_example
<PROTOCOL:PATHANGLE>
#+end_example

+ PROTOCOL :: A string which is one of the link type strings in
  ~org-link-parameters~[fn:olp]
+ PATHANGLE :: A string containing any character but =]=, =<=, =>= or =\n=.

The angle brackets allow for a more permissive PATH syntax, without
accidentally matching surrounding text.

* Fields

#+begin_src julia
path::LinkPath
#+end_src
""" AngleLink

@doc org"""
*Org Syntax Reference*: \S4.10.4 \\
*Org Component Type*: Object

* Forms

#+begin_example
[[PATHREG]]
[[PATHREG][DESCRIPTION]]
#+end_example

+ PATHREG :: An instance of one of the seven following annotated patterns:
  #+begin_example
FILENAME               ("file" type)
PROTOCOL:PATHINNER     ("PROTOCOL" type)
PROTOCOL://PATHINNER   ("PROTOCOL" type)
id:ID                  ("id" type)
#CUSTOM-ID             ("custom-id" type)
(CODEREF)              ("coderef" type)
FUZZY                  ("fuzzy" type)
  #+end_example
  - FILENAME :: A string representing an absolute or relative file path.
  - PROTOCOL :: A string which is one of the link type strings in
    ~org-link-parameters~[fn:olp]
  - PATHINNER :: A string consisting of any character besides square brackets.
  - ID :: A string consisting of hexadecimal numbers separated by hyphens.
  - CUSTOM-ID :: A string consisting of any character besides square brackets.
  - CODEREF :: A string consisting of any character besides square brackets.
  - FUZZY :: A string consisting of any character besides square brackets.
  Square brackets and backslashes can be present in PATHREG so long as
  they are escaped by a backslash (i.e. =\]=, =\\=).
+ DESCRIPTION (optional) :: A series of objects enclosed by square
  brackets.  It can contain the minimal set of objects as well as
  *export snippets*, *inline babel calls*, *inline source blocks*, *macros*,
  and *statistics cookies*.  It can also contain another link, but only
  when it is a plain or angle link.  It can contain square brackets,
  so long as they are balanced.

* Examples

#+begin_example
[[https://orgmode.org][The Org project homepage]]
[[file:orgmanual.org]]
[[Regular links]]
#+end_example

* Fields

#+begin_src julia
path::LinkPath
description::Union{Vector{Object}, Nothing}
#+end_src
""" RegularLink

@doc org"""
*Org Syntax Reference*: \S4.11 \\
*Org Component Type*: Object

* Forms

#+begin_example
{{{NAME}}}
{{{NAME(ARGUMENTS)}}}
#+end_example

+ NAME :: A string starting with a alphabetic character followed by
  any number of alphanumeric characters, hyphens and underscores (=-_=).
+ ARGUMENTS (optional) :: A string consisting of any characters, so
  long as it does not contain the substring =}}}=.  Values within
  ARGUMENTS are separated by commas.  Non-separating commas have to be
  escaped with a backslash character.

* Examples
#+begin_example
{{{title}}}
{{{one_arg_macro(1)}}}
{{{two_arg_macro(1, 2)}}}
{{{two_arg_macro(1\,a, 2)}}}
#+end_example

* Fields

#+begin_src julia
name::AbstractString
arguments::Vector{AbstractString}
#+end_src
""" Macro

@doc org"""
*Org Syntax Reference*: \S4.12 \\
*Org Component Type*: Object

* Forms

#+begin_example
<<<CONTENTS>>>
#+end_example

+ CONTENTS :: A series of objects from the minimal set, starting and
  ending with a non-whitespace character, and containing any character
  but =<=, =>=, or =\n=.

* Fields

#+begin_src julia
contents::Vector{Object}
#+end_src
""" RadioTarget

@doc org"""
*Org Syntax Reference*: \S4.12 \\
*Org Component Type*: Object

* Forms

#+begin_example
<<TARGET>>
#+end_example

+ TARGET :: A string containing any character but =<=, =>=, or =\n=.  It
  cannot start or end with a whitespace character.

* Fields

#+begin_src julia
contents::AbstractString
#+end_src
""" Target

@doc org"""
*Org Syntax Reference*: \S4.13 \\
*Org Component Type*: Object

* Forms

#+begin_example
[PERCENT%]
[NUM1/NUM2]
#+end_example

+ PERCENT (optional) :: A number.
+ NUM1 (optional) :: A number.
+ NUM2 (optional) :: A number.

* Fields

The subtype =StatisticsCookiePercent= has the following structure:
#+begin_src julia
percentage::AbstractString
#+end_src

The subtype =StatisticsCookieFraction= has the following structure:
#+begin_src julia
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
*Org Syntax Reference*: \S4.14 \\
*Org Component Type*: Object

* Forms
#+begin_src org
CHAR_SCRIPT
CHAR^SCRIPT
#+end_src

+ CHAR :: Any non-whitespace character.
+ SCRIPT :: One of the following constructs:
  - A single asterisk character (=*=).
  - An expression enclosed in curly brackets (={=, =}=), which may itself
    contain balanced curly brackets.
  - An instance of the pattern:
    #+begin_example
SIGN CHARS FINAL
    #+end_example
    With no whitespace between SIGN, CHARS and FINAL.
    + SIGN :: Either a plus sign character (=+=), a minus sign character
      (=-=), or the empty string.
    + CHARS :: Either the empty string, or a string consisting of any
      number of alphanumeric characters, commas, backslashes, and
      dots.
    + FINAL :: An alphanumeric character.

* Fields

Each of the subtypes, =Subscript= and =Superscript= are of the form:
#+begin_src
char::Char
script::AbstractString
#+end_src
""" Script

@doc org"""
*Org Syntax Reference*: \S4.15 \\
*Org Component Type*: Object

* Forms

#+begin_example
CONTENTS SPACES|
#+end_example

+ CONTENTS :: A series of objects not containing the vertical bar
  character (=|=).  It can contain the minimal set of objects,
  *citations*, *export snippets*, **footnote references*, *links*, *macros*,
  *radio targets*, *targets*, and *timestamps*.
+ SPACES :: A string consisting of zero or more of space characters,
  used to align the table columns.

The final vertical bar (=|=) may be omitted in the last cell of a row.

* Fields

#+begin_src julia
contents::Vector{Object}
#+end_src
""" TableCell

@doc org"""
*Org Syntax Reference*: \S4.16 \\
*Org Component Type*: Object

* Forms

#+begin_example
<%%(SEXP)>                                                     (diary)
<DATE TIME REPEATER-OR-DELAY>                                  (active)
[DATE TIME REPEATER-OR-DELAY]                                  (inactive)
<DATE TIME REPEATER-OR-DELAY>--<DATE TIME REPEATER-OR-DELAY>   (active range)
<DATE TIME-TIME REPEATER-OR-DELAY>                             (active range)
[DATE TIME REPEATER-OR-DELAY]--[DATE TIME REPEATER-OR-DELAY]   (inactive range)
[DATE TIME-TIME REPEATER-OR-DELAY]                             (inactive range)
#+end_example

+ SEXP :: A string consisting of any characters but =>= and =\n=.
+ DATE :: An instance of the pattern:
  #+begin_example
YYYY-MM-DD DAYNAME
  #+end_example
  - Y, M, D :: A digit.
  - DAYNAME (optional) :: A string consisting of non-whitespace
    characters except =+=, =-=, =]=, =>=, a digit, or =\n=.
+ TIME (optional) :: An instance of the pattern =H:MM= where =H= represents a one to
  two digit number (and can start with =0=), and =M= represents a single
  digit.
+ REPEATER-OR-DELAY (optional) :: An instance of the following pattern:
  #+begin_example
MARK VALUE UNIT
  #+end_example
  Where MARK, VALUE and UNIT are not separated by whitespace characters.
  - MARK :: Either the string =+= (cumulative type), =++= (catch-up type),
    or =.+= (restart type) when forming a repeater, and either =-= (all
    type) or =--= (first type) when forming a warning delay.
  - VALUE :: A number
  - UNIT :: Either the character =h= (hour), =d= (day), =w= (week), =m=
    (month), or =y= (year)

There can be two instances of =REPEATER-OR-DELAY= in the timestamp: one
as a repeater and one as a warning delay.

* Examples
#+begin_example
<1997-11-03 Mon 19:15>
<%%(diary-float t 4 2)>
[2004-08-24 Tue]--[2004-08-26 Thu]
<2012-02-08 Wed 20:00 ++1d>
<2030-10-05 Sat +1m -3d>
#+end_example

* Fields

There are a large number of subtypes.\\
TODO fill in more info
""" Timestamp

@doc org"""
*Org Syntax Reference*: \S4.17 \\
*Org Component Type*: Object

There are six text markup objects: bold, italic, underline,
verbatim, code, and strike-through.  They are all shadowed
by this type.

* Forms

#+begin_example
PRE MARKER CONTENTS MARKER POST
#+end_example

Where PRE, MARKER, CONTENTS, MARKER and /POST/ are not separated by
whitespace characters.

+ PRE :: Either a whitespace character, =-=, =(=, ={=, ='=, ="=, or the beginning
  of a line.
+ MARKER :: A character that determines the object type, as follows:
  - =*=, a /bold/ object,
  - =/=, an /italic/ object,
  - =_= an /underline/ object,
  - ===, a /verbatim/ object,
  - =~=, a /code/ object
  - =+=, a /strike-through/ object.
+ CONTENTS :: An instance of the pattern:
  #+begin_example
BORDER BODY BORDER
  #+end_example
  Where BORDER and BODY are not separated by whitespace.
  - BORDER :: Any non-whitespace character.
  - BODY ::  Either a string (when MARKER represents code or verbatim)
    or a series of objects from the standard set, not spanning more
    than three lines.
+ POST :: Either a whitespace character, =-=, =.=, =,=, =;=, =:=, =!=, =?=, ='=, =)=, =}=,
  =[=, ="=, or the end of a line.

* Fields
#+begin_src julia
formatting::Symbolcontents::Vector{Object}
contents::Union{Vector{Object}, <:AbstractString}
#+end_src
""" TextMarkup

@doc org"""
*Org Syntax Reference*: \S4.18 \\
*Org Component Type*: Object

Any string that doesn't match any other object can be considered a
plain text object.
Within a plain text object, all whitespace is collapsed to a single
space. For instance, =hello\n there= is equivalent to =hello there=.

* Fields

#+begin_src julia
text::AbstractString
#+end_src
""" TextPlain
