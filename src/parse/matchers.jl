# Matchers for Components  -*- mode: julia; -*-

orgmatcher(::Type{<:Component}) = nothing

# ---------------------
# Sections
# ---------------------

@inline orgmatcher(::Type{Heading}) = r"^(\*+)(?: +([A-Z]{2,}))?(?: +\[#([A-Z0-9])\])? +([^\n]*?)(?: +(:[A-Za-z0-9_\@#%][A-Za-z0-9_\@#%:]*:))?(?:[\n \t]*\n|$)((?:(?!\*+ )[^\n]+\n*)+)?"
@inline orgmatcher(::Type{Section}) = r"^\n*((?:\n*?(?!\*+ )[^\n]+)+)(?:\n(?:[ \t\r]*\n)*|$)"

# ---------------------
# Greater Elements
# ---------------------

abstract type ParagraphForced end

const org_element_matchers =
    Dict{Char, Vector{<:Type}}(
        '#' => [BabelCall, AffiliatedKeywordsWrapper, DynamicBlock, Keyword, Block, GreaterBlock, Comment],
        '-' => [HorizontalRule, List],
        '|' => [Table],
        ':' => [Drawer, FixedWidth],
        '%' => [DiarySexp],
        '+' => [List],
        '*' => [List],
        '[' => [FootnoteDefinition],
        '\\' => [LaTeXEnvironment],
        'c' => [Clock],
        'C' => [Clock])

const org_element_fallbacks = [Paragraph, List, ParagraphForced]

# Greater Block
@inline orgmatcher(::Type{GreaterBlock}) = r"^[ \t]*#\+begin_(\S+)(?: ([^\n]+?))?[ \t]*?(?:\n((?!\*+ )[^\n]*(?:\n(?!\*+ )[^\n]*)*?))?\n[ \t]*#\+end_\1(?:\n(?:[ \t\r]*\n)*|$)"i
@inline orgmatcher(::Type{Drawer}) = r"^[ \t]*:([\w\-_]+):\n([\s\S]+?)?\n?:END:(?:\n(?:[ \t\r]*\n)*|$)"i
@inline orgmatcher(::Type{DynamicBlock}) = r"^[ \t]*#\+begin:[ \t]+(\S+)(?: ([^\n]+?))?[ \t]*?(?:\n((?!\*+ )[^\n]*(?:\n(?!\*+ )[^\n]*)*?))?\n[ \t]*#\+end:(?:\n(?:[ \t\r]*\n)*|$)"i
# FootnoteDefinition has a dedicated consumer
# InlineTask
@inline orgmatcher(::Type{PropertyDrawer}) = r"^[ \t]*:PROPERTIES:\n((?:[ \t]*:[^\+\n]+\+?:(?:[ \t]+[^\n]*|[ \t]*)?\n??)*)\n?[ \t]*:END:(?:[\n \t]*\n|$)"i
@inline orgmatcher(::Type{Table}) = r"^([ \t]*\|[^\n]*(?:\n[ \t]*\|[^\n]+)*)((?:\n[ \t]*#\+TBLFM: [^\n]*)+)?(?:\n(?:[ \t\r]*\n)*|$)"
# List and Item have dedicated consumers
@inline orgmatcher(::Type{List}) = r"^([ \t]*)(\+|\-| \*|(?:[A-Za-z]|[0-9]+)[\.\)]) "
@inline orgmatcher(::Type{Item}) = r"^([ \t]*)(\+|\-| \*|(?:[A-Za-z]|[0-9]+)[\.\)]) "

# ---------------------
# Elements
# ---------------------

@inline orgmatcher(::Type{BabelCall}) = r"^[ \t]*#\+call:[ \t]*([^\n]*)(?:\n(?:[ \t\r]*\n)*|$)"i
@inline orgmatcher(::Type{Block}) = r"^[ \t]*#\+begin_(comment|example|export|src|verse)(?: ([^\n]+?))?[ \t]*?(?:\n((?!\*+ )[^\n]*(?:\n(?!\*+ )[^\n]*)*?))?\n[ \t]*#\+end_\1(?:\n(?:[ \t\r]*\n)*|$)"i
# Clock has a custom consumer
@inline orgmatcher(::Type{DiarySexp}) = r"^%%(\(.*\))[ \t\r]*(?:\n(?:[ \t\r]*\n)*|$)"
# Planning has a custom consumer
@inline orgmatcher(::Type{Comment}) = r"^([ \t]*#(?:| [^\n]*)(?:\n[ \t]*#(?:\n| [^\n]*))*)(?:\n(?:[ \t\r]*\n)*|$)"
@inline orgmatcher(::Type{FixedWidth}) = r"^([ \t]*:(?:| [^\n]*)(?:\n[ \t]*:(?:\n| [^\n]*))*)(?:\n(?:[ \t\r]*\n)*|$)"
@inline orgmatcher(::Type{HorizontalRule}) = r"^[ \t]*-{5,}[ \t]*(?:\n(?:[ \t\r]*\n)*|$)"
@inline orgmatcher(::Type{Keyword}) = r"^[ \t]*#\+(\S+?):(?:[ \t]+?([^\n]*))?(?:\n(?:[ \t\r]*\n)*|$)"
@inline orgmatcher(::Type{LaTeXEnvironment}) = r"^([ \t]*)\\begin{([A-Za-z*]*)}([\s\S]*)\n[ \t]*\\end{\2}(?:[ \t\r\n]*\n|$)"
@inline orgmatcher(::Type{NodeProperty}) = r"^[ \t]*:([^\+\n]+)(\+)?:([ \t]+[^\n]*|[ \t]*)(?:\n(?:[ \t\r]*\n)*|$)"
@inline orgmatcher(::Type{Paragraph}) = r"^[ \t]*+((?!\*+ |#\+\S|\[fn:([A-Za-z0-9-_]+)\] |[ \t]*(?:[*\-\+]|[A-Za-z]\.|\d+\.)[ \t]|:([\w\-_]+):(?:\n(?:[ \t\r]*\n)*|$)|\||#\n|# |:\n|: |[ \t]*\-{5,}[ \t]*(?:\n(?:[ \t\r]*\n)*|$)|\\begin\{)[^\n]+(?:\n[ \t]*+(?!\*+ |#\+\S|\[fn:([A-Za-z0-9-_]*)\] |[ \t]*(?:[*\-\+]|[A-Za-z]\.|\d+\.)[ \t]|:([\w\-_]+):(?:\n(?:[ \t\r]*\n)*|$)|\||#\n|# |:\n|: |[ \t]*\-{5,}[ \t]*(?:\n(?:[ \t\r]*\n)*|$)|\\begin\{)[^\n]+)*)(?:\n(?:[ \t\r]*\n)*|$)"
@inline orgmatcher(::Type{TableRow}) = r"^[ \t]*(\|[^\n]*)(?:\n(?:[ \t\r]*\n)*|$)"
@inline orgmatcher(::Type{TableHrule}) = r"^|[\-\+]+|"

# ---------------------
# Objects
# ---------------------

# Force matching
abstract type TextPlainForced end

# Matchers

const org_object_matchers =
    Dict{Char, Vector{<:Type}}(
        '[' => [RegularLink, Timestamp, StatisticsCookie, FootnoteReference, Citation],
        '{' => [Macro],
        '<' => [RadioTarget, Target, AngleLink, Timestamp],
        '\\' => [LineBreak, Entity, LaTeXFragment],
        '$' => [LaTeXFragment],
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

const org_object_fallbacks =
    [PlainLink, TextPlain, TextMarkup, Script, TextPlainForced]

# Entity has a custom consumer

@inline orgmatcher(::Type{LaTeXFragment}) = r"^(\\[A-Za-z]+(?:{[^{}\n]*}|\[[^][{}\n]*\])*)|(\\\(.*?\\\)|\\\[.*?\\\]|\$.*?\$)"
@inline orgmatcher(::Type{ExportSnippet}) = r"^\@\@([A-Za-z0-9-]+):(.*?)\@\@"
# FootnoteReference has a dedicated consumer
@inline orgmatcher(::Type{InlineBabelCall}) = r"^call_([^()\n]+?)(?:(\[[^]\n]+\]))?\(([^)\n]*)\)(?:(\[[^]\n]+\]))?"
# OrgInlineSource has a custom consumer
@inline orgmatcher(::Type{LineBreak}) = r"^\\\\[ \t]*(?:\n *|$)"
@inline orgmatcher(::Type{PlainLink}) = r"^([^:#*<>()\[\]{}\s]+:(?:[^ \t\n\[\]<>()]|\((?:[^ \t\n\[\]<>()]|\([^ \t\n\[\]<>()]*\))*\))+(?:[^[:punct:] \t\n]|\/|\((?:[^ \t\n\[\]<>()]|\([^ \t\n\[\]<>()]*\))*\)))"
@inline orgmatcher(::Type{AngleLink}) = r"<([^:#*<>()\[\]{}\s]+:[^>\n]*(?:\n[^>\n]*)*)>"
@inline orgmatcher(::Type{Macro}) = r"^{{{([A-Za-z][A-Za-z0-9-_]*?)(?:\((.*?)\))?}}}"
@inline orgmatcher(::Type{RadioTarget}) = r"^<<<(.*?)>>>"
@inline orgmatcher(::Type{Target}) = r"^<<(.*?)>>"
@inline orgmatcher(::Type{StatisticsCookie}) = r"^\[([\d.]*%)\]|^\[(\d+)?\/(\d+)?\]"
@inline orgmatcher(::Type{Script}) = r"^(\S)([_^])({.*}|[+-]?[A-Za-z0-9-\\.]*[A-Za-z0-9])"
@inline orgmatcher(::Type{TableCell}) = r"^|[^|\n]+|"

@inline orgmatcher(::Type{TimestampActive}) = r"<\d{4}-\d\d-\d\d(?: \d?\d:\d\d)?(?: [A-Za-z]{3,7})?>"
@inline orgmatcher(::Type{TimestampInactive}) = r"\[\d{4}-\d\d-\d\d(?: \d?\d:\d\d)?(?: [A-Za-z]{3,7})?\]"
# Timestamp has a custom consumer

# TextMarkup has a custom consumer
# TextPlain has a custom consumer
