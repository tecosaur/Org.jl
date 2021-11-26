# Matchers for OrgComponents

orgmatcher(::Type{<:OrgComponent}) = nothing

# ---------------------
# Sections
# ---------------------

@inline orgmatcher(::Type{Heading}) = r"^(\*+)(?: +([A-Z]{2,}))?(?: +\[#([A-Z0-9])\])? +([^\n]*?)(?: +(:[A-Za-z0-9_\@#%][A-Za-z0-9_\@#%:]*:))?(?:\n+|$)((?:(?!\*+ )[^\n]+\n*)+)?"
@inline orgmatcher(::Type{Section}) = r"^((?:(?!\*+ )[^\n]+\n*)+)"

# ---------------------
# Greater Elements
# ---------------------

# Greater Block
@inline orgmatcher(::Type{Drawer}) = r"^:([\w\-_]+):\n(.*?)\n:END:(?:\n|$)"
# Dynamic Block
# Footnote Def r"^\[fn:([A-Za-z0-9-_]*)\] "
# InlineTask
# List
@inline orgmatcher(::Type{List}) = r"^([ \t]*)([*\-\+] [^\n]+(?:\n(?:\1  |\1[*\-\+] )[^\n]+)*)(?:\n|$)"
@inline orgmatcher(::Type{Item}) = r"^([ \t]*)([*\-\+]|(?:[A-Za-z]|[0-9]+)[\.\)])(?:\s+\[\@([A-Za-z]|[0-9]+)\])?(?:\s+\[([ \-X])\])?(?:\s+([^\n]+)::)?\s+((?:[^\n]+(?:\n\1  )?)*)(?:\n|$)"
# PropertyDrawer
@inline orgmatcher(::Type{Table}) = r"^([ \t]*\|[^\n]+(?:\n[ \t]*\|[^\n]+)*)((?:\n[ \t]*#\+TBLFM: [^\n]*)+)?"m

# ---------------------
# Elements
# ---------------------

@inline orgmatcher(::Type{BabelCall}) = r"^[ \t]*#\+call:\s*([^\n]*)(?:\n|$)"
@inline orgmatcher(::Type{Block}) = r"^[ \t]*#\+begin_(\S+)(?: ([^\n]+))?\n((?:(?!\*)[^\n]*\n)*?(?!\*)[^\n]*)\n?[ \t]*#\+end_\1(?:\n|$)"
# DiarySexp
@inline orgmatcher(::Type{Comment}) = r"^[ \t]*#(\n| [^\n]*)(?:\n|$)"
@inline orgmatcher(::Type{FixedWidth}) = r"^[ \t]*:(\n| [^\n]*)(?:\n|$)"
@inline orgmatcher(::Type{HorizontalRule}) = r"^[ \t]*-{5,}\s*(?:\n|$)"
@inline orgmatcher(::Type{Keyword}) = r"^[ \t]*#\+(\S+): (.*)\n?"
@inline orgmatcher(::Type{LaTeXEnvironment}) = r"^[ \t]*\\begin{([A-Za-z*]*)}\n(.*)\n[ \t]*\\end{\1}(?:\n|$)"
@inline orgmatcher(::Type{NodeProperty}) = r"^[ \t]*:([^\+]+)(\+)?:\s+([^\n]*)"
@inline orgmatcher(::Type{Paragraph}) = r"^[ \t]*((?:(?!\*+ |#\+|\[fn:([A-Za-z0-9-_]*)\] |[ \t]*[*\-\+][ \t]|:([\w\-_]+):(?:\n|$)|\||#\n|# |:\n|: |\s*\-{5,}\s*(?:\n|$)|\\begin\{)[^\n]+\n?)+)(?:\n|$)"
@inline orgmatcher(::Type{TableRow}) = r"^[ \t]*(\|[^\n]*)(?:\n|$)"
# Table Hrule
@inline orgmatcher(::Type{EmptyLine}) = r"\n+"

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
forwardsinlinesrc(content::AbstractString, point::Integer) =
    forwardsbalenced(content, point; bracketpairs=Dict('{' => '}'),
                     escapechars=['\\'], quotes=['"'])
orgmatcher(::Type{InlineSourceBlock}) = function(content::AbstractString)
    srcmatch = match(r"^src_(\S+?)(?:\[([^\n]+)\])?{", content)
    if !isnothing(srcmatch)
        codeend = forwardsinlinesrc(content, length(srcmatch.match))
        if !isnothing(codeend)
            @inbounds @view content[1:codeend]
        end
    end
end
@inline orgmatcher(::Type{LineBreak}) = r"^\\\\\s*(?:\n *|$)"
@inline orgmatcher(::Type{Link}) = r"^\[\[([^]]+)\](?:\[([^]]+)\])?\]"
@inline orgmatcher(::Type{Macro}) = r"^{{{([A-Za-z][A-Za-z0-9-_]*)\((.*)\)}}}"
# Radio Target
@inline orgmatcher(::Type{RadioTarget}) = r"^<<<(.*?)>>>"
@inline orgmatcher(::Type{Target}) = r"^<<(.*?)>>"
@inline orgmatcher(::Type{StatisticsCookie}) = r"^\[([\d.]*%)\]|^\[(\d+)?\/(\d+)?\]"
@inline orgmatcher(::Type{Script}) = r"^(\S)([_^])({.*}|[+-]?[A-Za-z0-9-\\.]*[A-Za-z0-9])"
# Table Cell
@inline orgmatcher(::Type{TimestampActive}) = r"<\d{4}-\d\d-\d\d(?: \d?\d:\d\d)?(?: [A-Za-z]{3,7})?>"
@inline orgmatcher(::Type{TimestampInactive}) = r"\[\d{4}-\d\d-\d\d(?: \d?\d:\d\d)?(?: [A-Za-z]{3,7})?\]"
# Timestamp
@inline orgmatcher(::Type{TextMarkup}) = r"^(^|[\s\-({'\"])([*\/+_~=])(\S.*?(?<=\S))\2([]\s\-.,;:!?')}\"]|$)"
orgmatcher(::Type{TextPlain}) = function(content::AbstractString)
    alph(c) = c in 'a':'z' || c in 'A':'Z'
    alphnum(c) = alph(c) || c in '0':'9'
    spc(c) = c in [' ', '\t', '\n']
    if content[1] in 'A':'z'
        # last index, current index, next index
        li, i, ni = 1, 2, nextind(content, 2)
        clen = lastindex(content)
        while i < clen
            # last char, current char, next char
            lc, c, nc = content[li], content[i], content[ni]
            if alphnum(c) || c in [' ', '\t']
            elseif c in ['+', '-', '*'] && lc == '\n' && spc(nc) # list items
                return @inbounds @view content[1:i-1]
            elseif c == '|' && lc == '\n'
                return @inbounds @view content[1:i-1]
            elseif c == '^' && (nc in ['{', '+', '-'] || alphnum(nc)) # superscripts
                return @inbounds @view content[1:i-1]
            elseif c == '_' && !spc(lc) && !spc(nc)
                if 5 < i && content[i-4] == 'c' # inline babel call
                    return @inbounds @view content[1:i-5]
                elseif 4 < i && content[i-3] == 's' # inline src block
                    return @inbounds @view content[1:i-4]
                else # subscript
                    return @inbounds @view content[1:i-1]
                end
            elseif c == '[' && (nc == 'f' || nc in '0':'9') # footnotes & inactive timestamps & statistics cookies
                return @inbounds @view content[1:i-1]
            elseif c == '{' && nc == '{' && i+1 < clen && content[i+2] == '{' # macro
                return @inbounds @view content[1:i-1]
            elseif c == '@' && nc == '@' # export snippet
                return @inbounds @view content[1:i-1]
            elseif c in ['*', '/', '+', '_', '~', '='] && spc(lc) && !spc(nc) # markup
                return @inbounds @view content[1:i-2]
            elseif c == '\\' && !spc(nc) # entities & latex & line break
                return @inbounds @view content[1:i-1]
            elseif c == '<' && (nc == '<' || nc in '0':'9') # targets & active timestamps
                return @inbounds @view content[1:i-1]
            end
            li, i, ni = i, ni, nextind(content, ni)
        end
        return content
    end
end
