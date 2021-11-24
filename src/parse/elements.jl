abstract type OrgElement <: OrgComponent end # Org Syntax §4
include("objects.jl") # Org Syntax §5

mutable struct BabelCall <: OrgElement # Org Syntax §4.1
    name::AbstractString
end
const BabelCallRegexp = r"^[ \t]*#\+call:\s*([^\n]*)"

mutable struct Block <: OrgElement # Org Syntax §4.2
    name::AbstractString
    data::Union{AbstractString, Nothing}
    contents::AbstractString
end
const BlockRegexp = r"^[ \t]*#\+begin_(\S+)( [^\n]+)?\n(.*)\n[ \t]*#\+end_\1"
function Block(content::AbstractString)
    blockmatch = match(Regex("^$(BlockRegexp.pattern)"), content)
    @parseassert(Block, !isnothing(blockmatch),
                 "did not match any recognised block form\n$content")
    name, data, contents = blockmatch.captures
    Block(name, data, contents)
end

mutable struct DiarySexp <: OrgElement end # Org Syntax §4.3

mutable struct Planning <: OrgElement end # Org Syntax §4.3

mutable struct Comment <: OrgElement # Org Syntax §4.4
    contents::AbstractString
end

mutable struct FixedWidth <: OrgElement # Org Syntax §4.5
    contents::AbstractString
end

struct HorizontalRule <: OrgElement end # Org Syntax §4.6
const HorizontalRuleRegex = r"^[ \t]*-{5,}\s*$"

mutable struct Keyword <: OrgElement # Org Syntax §4.7
    key::AbstractString
    value::AbstractString
end
const KeywordRegex = r"^[ \t]*#\+(\S+): (.*)"
function Keyword(content::AbstractString)
    keywordmatch = match(KeywordRegex, content)
    @parseassert(Keyword, !isnothing(keywordmatch),
                 "\"$content\"did not match any recognised form")
    key, value = keywordmatch.captures
    Keyword(key, value)
end

mutable struct LaTeXEnvironment <: OrgElement # Org Syntax §4.8
    name::AbstractString
    contents::AbstractString
end
const LaTeXEnvironmentRegex = r"^[ \t]*\\begin{([A-Za-z*]*)}\n(.*)\n[ \t]*\\end{\1}"
function LaTeXEnvironment(content::AbstractString)
    latexenvmatch = match(LaTeXEnvironmentRegex, content)
    @parseassert(LaTeXEnvironment, !isnothing(latexenvmatch),
                 "did not match any recognised form\n$content")
    name, content = latexenvmatch.captures
    LaTeXEnvironment(name, content)
end

mutable struct NodeProperty <: OrgElement # Org Syntax §4.9
    name::AbstractString
    additive::Bool
    value::AbstractString
end
const NodePropertyRegex = r":([^\+]+)(\+)?:\s+([^\n]*)"
function NodeProperty(content::AbstractString)
    nodepropmatch = match(NodeProperty, content)
    @parseassert(NodeProperty, !isnothing(nodepropmatch),
                 "\"$content\" did not match any recognised form")
    name, additive, value = nodepropmatch.captures
    NodeProperty(name, isnothing(additive), value)
end

mutable struct Paragraph <: OrgElement # Org Syntax §4.10
    objects::Vector{OrgObject}
end
Paragraph(content::String) = Paragraph(parseinlineorg(content))

mutable struct TableRow <: OrgElement # Org Syntax §4.11
    cells::Vector{TableCell}
end
struct TableHrule <: OrgElement end
function TableRow(content::AbstractString)
    TableRow(TableCell.(split(strip(content, '|'), '|')))
end

struct EmptyLine <: OrgElement end
