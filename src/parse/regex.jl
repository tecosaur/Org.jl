# Regex to locate and test for OrgComponents

# ---------------------
# Sections
# ---------------------

const HeadingRegex = r"^(\*+)(?: +([A-Z]{2,}))?(?: +\[#([A-Z0-9])\])? +([^\n]*?)(?: +(:[A-Za-z0-9_\@#%][A-Za-z0-9_\@#%:]*:))?$"

# ---------------------
# Greater Elements
# ---------------------

# Greater Block
const DrawerRegex = r"^:([\w\-_]+):\n(.*?)\n:END:"
# Dynamic Block
const FootnoteDefRegex = r"^\[fn:([A-Za-z0-9-_]*)\] "
# InlineTask
const ItemRegex = r"^([*\-\+]|(?:[A-Za-z]|[0-9]+)[\.\)])(?:\s+\[\@([A-Za-z]|[0-9]+)\])?(?:\s+\[([ \-X])\])?(?:\s+([^\n]+)::)?\s+(.*)"
# List
# PropertyDrawer
const TableRegex = r"^([ \t]*\|[^\n]+(?:\n[ \t]*\|[^\n]+)*)((?:\n[ \t]*#\+TBLFM: [^\n]*)+)?"m

# ---------------------
# Elements
# ---------------------

const BabelCallRegexp = r"^[ \t]*#\+call:\s*([^\n]*)"
const BlockRegexp = r"^[ \t]*#\+begin_(\S+)( [^\n]+)?\n(.*)\n[ \t]*#\+end_\1"
# DiarySexp
# Comment
# Fixed Width
const HorizontalRuleRegex = r"^[ \t]*-{5,}\s*$"
const KeywordRegex = r"^[ \t]*#\+(\S+): (.*)"
const LaTeXEnvironmentRegex = r"^[ \t]*\\begin{([A-Za-z*]*)}\n(.*)\n[ \t]*\\end{\1}"
const NodePropertyRegex = r":([^\+]+)(\+)?:\s+([^\n]*)"
# Paragraph
# Table Row
# Table Hrule

# ---------------------
# Objects
# ---------------------

const EntityRegex = r"\\([A-Za-z]*)(.*)"
const LaTeXFragmentRegex = r"\\[A-Za-z]+(?:{.*})?|\\\(.*?\\\)|\\[.*?\\]"
const ExportSnippetRegex = r"\@\@.+:.*?\@\@"
const FootnoteRefRegex = r"\[fn:(?:[^:]+|:.+|[^:]+:.+)\]"
const InlineBabelCallRegex = r"call_([^()\n]+?)(?:(\[[^]\n]+\]))?\(([^)\n]*)\)(?:(\[[^]\n]+\]))?"
const InlineSourceBlockRegex = r"src_(\S+?)(?:(\[[^\n]+\]))?{([^\n]*)}"
const LineBreakRegex = r"\\\\\s*(?:\n *|$)"
const LinkRegex = r"\[\[([^]]+)\](?:\[([^]]+)\])?\]"
const MacroRegex = r"{{{([A-Za-z][A-Za-z0-9-_]*)\((.*)\)}}}"
# Radio Target
const RadioTargetRegex = r"<<<.*?>>>"
const TargetRegex = r"<<.*?>>"
const StatisticsCookieRegex = r"\[(?:[\d.]*%|\d*/\d*)\]"
const ScriptRegex = r"(\S)([_^])({.*}|[+-][A-Za-z0-9-\\.]*[A-Za-z0-9])"
# Table Cell
const TimestampActiveRegex = r"<\d{4}-\d\d-\d\d(?: \d?\d:\d\d)?(?: [A-Za-z]{3,7})?>"
const TimestampInactiveRegex = r"\[\d{4}-\d\d-\d\d(?: \d?\d:\d\d)?(?: [A-Za-z]{3,7})?\]"
# Timestamp
# Text Plain
const TextMarkupRegex = r"(^|[\s\-({'\"])([*\/+_~=])(\S.*?(?<=\S))\2([]\s\-.,;:!?')}\"]|$)"m
