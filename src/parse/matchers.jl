# Matchers for OrgComponents

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

orgmatcher(::Type{<:OrgComponent}) = nothing

# ---------------------
# Sections
# ---------------------

@inline orgmatcher(::Type{Heading}) = r"^(\*+)(?: +([A-Z]{2,}))?(?: +\[#([A-Z0-9])\])? +([^\n]*?)(?: +(:[A-Za-z0-9_\@#%][A-Za-z0-9_\@#%:]*:))?$"

# ---------------------
# Greater Elements
# ---------------------

# Greater Block
@inline orgmatcher(::Type{Drawer}) = r"^:([\w\-_]+):\n(.*?)\n:END:"
# Dynamic Block
@inline orgmatcher(::Type{FootnoteDef}) = r"^\[fn:([A-Za-z0-9-_]*)\] "
# InlineTask
@inline orgmatcher(::Type{Item}) = r"^([*\-\+]|(?:[A-Za-z]|[0-9]+)[\.\)])(?:\s+\[\@([A-Za-z]|[0-9]+)\])?(?:\s+\[([ \-X])\])?(?:\s+([^\n]+)::)?\s+(.*)"
# List
# PropertyDrawer
@inline orgmatcher(::Type{Table}) = r"^([ \t]*\|[^\n]+(?:\n[ \t]*\|[^\n]+)*)((?:\n[ \t]*#\+TBLFM: [^\n]*)+)?"m

# ---------------------
# Elements
# ---------------------

@inline orgmatcher(::Type{BabelCall}) = r"^[ \t]*#\+call:\s*([^\n]*)"
@inline orgmatcher(::Type{Block}) = r"^[ \t]*#\+begin_(\S+)( [^\n]+)?\n(.*)\n[ \t]*#\+end_\1"
# DiarySexp
# Comment
# Fixed Width
@inline orgmatcher(::Type{HorizontalRule}) = r"^[ \t]*-{5,}\s*$"
@inline orgmatcher(::Type{Keyword}) = r"^[ \t]*#\+(\S+): (.*)"
@inline orgmatcher(::Type{LaTeXEnvironment}) = r"^[ \t]*\\begin{([A-Za-z*]*)}\n(.*)\n[ \t]*\\end{\1}"
@inline orgmatcher(::Type{NodeProperty}) = r":([^\+]+)(\+)?:\s+([^\n]*)"
# Paragraph
# Table Row
# Table Hrule

# ---------------------
# Objects
# ---------------------

orgmatcher(::Type{Entity}) = function(content::AbstractString)
    entitymatch = match(r"^\\([A-Za-z]*)({}|[^A-Za-z]|$)", content)
    if !isnothing(entitymatch) && entitymatch.captures[1] in keys(Entities)
        entitymatch.match
    end
end
@inline orgmatcher(::Type{LaTeXFragment}) = r"^(\\[A-Za-z]+(?:{[^{}\n]*}|\[[^][{}\n]*\])*)|(\\\(.*?\\\)|\\\[.*?\\\])"
@inline orgmatcher(::Type{ExportSnippet}) = r"^\@\@([A-Za-z0-9-]+):(.*?)\@\@"
@inline orgmatcher(::Type{FootnoteRef}) = r"^\[fn:([^:]+)?(?::(.+))?\]"
@inline orgmatcher(::Type{InlineBabelCall}) = r"^call_([^()\n]+?)(?:(\[[^]\n]+\]))?\(([^)\n]*)\)(?:(\[[^]\n]+\]))?"
@inline orgmatcher(::Type{InlineSourceBlock}) = r"^src_(\S+?)(?:(\[[^\n]+\]))?{([^\n]*)}"
@inline orgmatcher(::Type{LineBreak}) = r"^\\\\\s*(?:\n *|$)"
@inline orgmatcher(::Type{Link}) = r"^\[\[([^]]+)\](?:\[([^]]+)\])?\]"
@inline orgmatcher(::Type{Macro}) = r"^{{{([A-Za-z][A-Za-z0-9-_]*)\((.*)\)}}}"
# Radio Target
@inline orgmatcher(::Type{RadioTarget}) = r"^<<<.*?>>>"
@inline orgmatcher(::Type{Target}) = r"^<<.*?>>"
@inline orgmatcher(::Type{StatisticsCookie}) = r"^\[([\d.]*%)\]|^\[(\d*)\/(\d*)\]"
@inline orgmatcher(::Type{Script}) = r"^(\S)([_^])({.*}|[+-][A-Za-z0-9-\\.]*[A-Za-z0-9])"
# Table Cell
@inline orgmatcher(::Type{TimestampActive}) = r"<\d{4}-\d\d-\d\d(?: \d?\d:\d\d)?(?: [A-Za-z]{3,7})?>"
@inline orgmatcher(::Type{TimestampInactive}) = r"\[\d{4}-\d\d-\d\d(?: \d?\d:\d\d)?(?: [A-Za-z]{3,7})?\]"
# Timestamp
@inline orgmatcher(::Type{TextMarkup}) = r"^(^|[\s\-({'\"])([*\/+_~=])(\S.*?(?<=\S))\2([]\s\-.,;:!?')}\"]|$)"
orgmatcher(::Type{TextPlain}) = gobbletextplain
