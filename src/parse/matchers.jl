# Matchers for OrgComponents

orgmatcher(::Type{<:OrgComponent}) = nothing

# ---------------------
# Sections
# ---------------------

@inline orgmatcher(::Type{Heading}) = r"^(\*+)(?: +([A-Z]{2,}))?(?: +\[#([A-Z0-9])\])? +([^\n]*?)(?: +(:[A-Za-z0-9_\@#%][A-Za-z0-9_\@#%:]*:))?(?:[\n \t]*\n|$)((?:(?!\*+ )[^\n]+\n*)+)?"
@inline orgmatcher(::Type{Section}) = r"^\n*((?:\n*?(?!\*+ )[^\n]+)+)(?:\n+|$)"

# ---------------------
# Greater Elements
# ---------------------

const OrgElementMatchers =
    Dict{Char, Vector{<:Type}}(
        '#' => [BabelCall, Keyword, Block, Comment],
        '-' => [HorizontalRule, List],
        '|' => [Table],
        ':' => [PropertyDrawer, Drawer, FixedWidth],
        '+' => [List],
        '*' => [List],
        '[' => [FootnoteDef],
        '\\' => [LaTeXEnvironment],
        '\n' => [EmptyLine])

const OrgElementFallbacks = [Paragraph, List]

# Greater Block
@inline orgmatcher(::Type{Drawer}) = r"^[ \t]*:([\w\-_]+):\n([\s\S]*?)\n?:END:(?:\n|$)"i
# Dynamic Block
# FootnoteDef has a dedicated consumer
# InlineTask
@inline orgmatcher(::Type{PropertyDrawer}) = r"^[ \t]*:PROPERTIES:\n((?:[ \t]*:[^\+\n]+\+?:(?:[ \t]+[^\n]*|[ \t]*)?\n??)*)\n?[ \t]*:END:(?:[\n \t]*\n|$)"i
@inline orgmatcher(::Type{Table}) = r"^([ \t]*\|[^\n]+(?:\n[ \t]*\|[^\n]+)*)((?:\n[ \t]*#\+TBLFM: [^\n]*)+)?(?:\n|$)"
# List and Item have dedicated consumers
@inline orgmatcher(::Type{List}) = r"^([ \t]*)(\+|\-| \*|(?:[A-Za-z]|[0-9]+)[\.\)]) "
@inline orgmatcher(::Type{Item}) = r"^([ \t]*)(\+|\-| \*|(?:[A-Za-z]|[0-9]+)[\.\)]) "

# ---------------------
# Elements
# ---------------------

@inline orgmatcher(::Type{BabelCall}) = r"^[ \t]*#\+call:[ \t]*([^\n]*)(?:\n|$)"i
@inline orgmatcher(::Type{Block}) = r"^[ \t]*#\+begin_(\S+)(?: ([^\n]+?))?[ \t]*?(?:\n((?!\*)[^\n]*(?:\n(?!\*)[^\n]*)*))?\n[ \t]*#\+end_\1(?:\n|$)"i
@inline orgmatcher(::Type{Clock}) = r"^[ \t]*clock: \[(\d{4}-\d\d-\d\d)(?: [A-Za-z]+)?(?: (\d?\d:\d\d)(?:-(\d?\d:\d\d))?)?(?: ((?:\+|\+\+|\.\+|-|--))([\d.]+)([hdwmy]))? *\](?(3)|(?:|-\[(\d{4}-\d\d-\d\d)(?: [A-Za-z]+)?(?: (\d?\d:\d\d))?(?: ((?:\+|\+\+|\.\+|-|--))([\d.]+)([hdwmy]))? *\]))(?:\n|$)"i
# Planning has a custom consumer
@inline orgmatcher(::Type{Comment}) = r"^([ \t]*#(?:| [^\n]*)(?:\n[ \t]*#(?:\n| [^\n]*))*)(?:\n|$)"
@inline orgmatcher(::Type{FixedWidth}) = r"^([ \t]*:(?:| [^\n]*)(?:\n[ \t]*:(?:\n| [^\n]*))*)(?:\n|$)"
@inline orgmatcher(::Type{HorizontalRule}) = r"^[ \t]*-{5,}[ \t]*(?:\n|$)"
@inline orgmatcher(::Type{Keyword}) = r"^[ \t]*#\+(\S+): *(.*)\n?"
@inline orgmatcher(::Type{LaTeXEnvironment}) = r"^[ \t]*\\begin{([A-Za-z*]*)}\n(.*)\n[ \t]*\\end{\1}(?:\n|$)"
@inline orgmatcher(::Type{NodeProperty}) = r"^[ \t]*:([^\+\n]+)(\+)?:([ \t]+[^\n]*|[ \t]*)(?:\n|$)"
@inline orgmatcher(::Type{Paragraph}) = r"^[ \t]*+((?!\*+ |#\+\S|\[fn:([A-Za-z0-9-_]+)\] |[ \t]*(?:[*\-\+]|[A-Za-z]\.|\d+\.)[ \t]|:([\w\-_]+):(?:\n|$)|\||#\n|# |:\n|: |[ \t]*\-{5,}[ \t]*(?:\n|$)|\\begin\{)[^\n]+(?:\n[ \t]*+(?!\*+ |#\+\S|\[fn:([A-Za-z0-9-_]*)\] |[ \t]*(?:[*\-\+]|[A-Za-z]\.|\d+\.)[ \t]|:([\w\-_]+):(?:\n|$)|\||#\n|# |:\n|: |[ \t]*\-{5,}[ \t]*(?:\n|$)|\\begin\{)[^\n]+)*)(?:\n|$)"
@inline orgmatcher(::Type{TableRow}) = r"^[ \t]*(\|[^\n]*)(?:\n|$)"
@inline orgmatcher(::Type{TableHrule}) = r"^|[\-\+]+|"
@inline orgmatcher(::Type{EmptyLine}) = r"[\n \t]*\n"

# ---------------------
# Objects
# ---------------------

# Force matching
abstract type TextPlainForce end

# Matchers

const OrgObjectMatchers =
    Dict{Char, Vector{<:Type}}(
        '[' => [Link, Timestamp, StatisticsCookie, FootnoteRef],
        '{' => [Macro],
        '<' => [RadioTarget, Target, Timestamp],
        '\\' => [LineBreak, Entity, LaTeXFragment],
        '*' => [TextMarkup],
        '/' => [TextMarkup],
        '_' => [TextMarkup],
        '+' => [TextMarkup],
        '=' => [TextMarkup],
        '~' => [TextMarkup],
        '@' => [ExportSnippet],
        'c' => [InlineBabelCall, Script, TextPlain],
        's' => [InlineSourceBlock, Script, TextPlain],
    )

const OrgObjectFallbacks =
    [TextPlain,
     TextMarkup,
     Script,
     TextPlainForce] # we *must* move forwards by some ammount, c.f. §4.10

# Entity has a custom consumer

@inline orgmatcher(::Type{LaTeXFragment}) = r"^(\\[A-Za-z]+(?:{[^{}\n]*}|\[[^][{}\n]*\])*)|(\\\(.*?\\\)|\\\[.*?\\\])"
@inline orgmatcher(::Type{ExportSnippet}) = r"^\@\@([A-Za-z0-9-]+):(.*?)\@\@"
# FootnoteRef has a dedicated consumer
@inline orgmatcher(::Type{InlineBabelCall}) = r"^call_([^()\n]+?)(?:(\[[^]\n]+\]))?\(([^)\n]*)\)(?:(\[[^]\n]+\]))?"
# OrgInlineSource has a custom consumer
@inline orgmatcher(::Type{LineBreak}) = r"^\\\\[ \t]*(?:\n *|$)"
@inline orgmatcher(::Type{Link}) = r"^\[\[([^]]+)\](?:\[([^]]+)\])?\]"
@inline orgmatcher(::Type{Macro}) = r"^{{{([A-Za-z][A-Za-z0-9-_]*)(?:\((.*)\))?}}}"
@inline orgmatcher(::Type{RadioTarget}) = r"^<<<(.*?)>>>"
@inline orgmatcher(::Type{Target}) = r"^<<(.*?)>>"
@inline orgmatcher(::Type{StatisticsCookie}) = r"^\[([\d.]*%)\]|^\[(\d+)?\/(\d+)?\]"
@inline orgmatcher(::Type{Script}) = r"^(\S)([_^])({.*}|[+-]?[A-Za-z0-9-\\.]*[A-Za-z0-9])"
@inline orgmatcher(::Type{TableCell}) = r"^|[^|\n]+|"

@inline orgmatcher(::Type{TimestampActive}) = r"<\d{4}-\d\d-\d\d(?: \d?\d:\d\d)?(?: [A-Za-z]{3,7})?>"
@inline orgmatcher(::Type{TimestampInactive}) = r"\[\d{4}-\d\d-\d\d(?: \d?\d:\d\d)?(?: [A-Za-z]{3,7})?\]"
# Timestamp has a custom consumer

@inline orgmatcher(::Type{TextMarkup}) = r"^(^|[\n \t\-({'\"])([*\/+_~=])(\S.*?\n?.*?(?<=\S))\2([\n \t\]\-.,;:!?')}\"]|$)" # TODO peek at start of string being applied to, to properly check PRE condition
# TextPlain has a custom consumer
