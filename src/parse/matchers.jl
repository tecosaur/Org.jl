# Matchers for OrgComponents

orgmatcher(::Type{<:OrgComponent}) = nothing

# ---------------------
# Sections
# ---------------------

@inline orgmatcher(::Type{Heading}) = r"^(\*+)(?: +([A-Z]{2,}))?(?: +\[#([A-Z0-9])\])? +([^\n]*?)(?: +(:[A-Za-z0-9_\@#%][A-Za-z0-9_\@#%:]*:))?(?:\n+|$)((?:(?!\*+ )[^\n]+\n*)+)?"
@inline orgmatcher(::Type{Section}) = r"^\n*((?:\n*?(?!\*+ )[^\n]+)+)(?:\n+|$)"

# ---------------------
# Greater Elements
# ---------------------

# Greater Block
@inline orgmatcher(::Type{Drawer}) = r"^[ \t]*:([\w\-_]+):\n([\s\S]*?)\n?:END:(?:\n|$)"i
# Dynamic Block
# Footnote Def r"^\[fn:([A-Za-z0-9-_]*)\] "
# InlineTask
@inline orgmatcher(::Type{List}) = r"^([ \t]*)((?:[*\-\+]|[A-Za-z]\.|\d+\.) [^\n]+(?:\n(?:\1  |\1(?:[*\-\+]|[A-Za-z]\.|\d+\.) )[^\n]+)*)(?:\n|$)"
@inline orgmatcher(::Type{Item}) = r"^([ \t]*)([*\-\+]|(?:[A-Za-z]|[0-9]+)[\.\)])(?:[ \t]+\[\@([A-Za-z]|[0-9]+)\])?(?:[ \t]+\[([ \-X])\])?(?:[ \t]+([^\n]+)::)?[ \t]+((?:[^\n]+(?:\n\1  )?)*)(?:\n|$)"
@inline orgmatcher(::Type{PropertyDrawer}) = r"^[ \t]*:PROPERTIES:\n((?:[ \t]*:[^\+\n]+\+?:(?:[ \t]+[^\n]*|[ \t]*)?\n??)*)\n?[ \t]*:END:(?:\n+|$)"i
@inline orgmatcher(::Type{Table}) = r"^([ \t]*\|[^\n]+(?:\n[ \t]*\|[^\n]+)*)((?:\n[ \t]*#\+TBLFM: [^\n]*)+)?(?:\n|$)"

# ---------------------
# Elements
# ---------------------

@inline orgmatcher(::Type{BabelCall}) = r"^[ \t]*#\+call:[ \t]*([^\n]*)(?:\n|$)"i
@inline orgmatcher(::Type{Block}) = r"^[ \t]*#\+begin_(\S+)(?: ([^\n]+?))?[ \t]*?(?:\n((?!\*)[^\n]*(?:\n(?!\*)[^\n]*)*))?\n[ \t]*#\+end_\1(?:\n|$)"i
@inline orgmatcher(::Type{Clock}) = r"^[ \t]*clock: \[(\d{4}-\d\d-\d\d)(?: [A-Za-z]+)?(?: (\d?\d:\d\d)(?:-(\d?\d:\d\d))?)?(?: ((?:\+|\+\+|\.\+|-|--))([\d.]+)([hdwmy]))? *\](?(3)|(?:|-\[(\d{4}-\d\d-\d\d)(?: [A-Za-z]+)?(?: (\d?\d:\d\d))?(?: ((?:\+|\+\+|\.\+|-|--))([\d.]+)([hdwmy]))? *\]))(?:\n|$)"i

orgmatcher(::Type{Planning}) = function (content::AbstractString)
    plan = Dict{String, Union{Nothing, Timestamp}}(
        "DEADLINE" => nothing,
        "SCHEDULED" => nothing,
        "CLOSED" => nothing)
    point = 1
    clen = ncodeunits(content)
    while point <= clen+1
        kwdmatch = match(r"^[ \t]*(DEADLINE|SCEDULED|CLOSED):[ \t]*", view(content, point:clen))
        if !isnothing(kwdmatch)
            point += ncodeunits(kwdmatch.match)
            tsmatch = consume(Timestamp, view(content, point:clen))
            if !isnothing(tsmatch)
                tstext, ts = tsmatch
                plan[kwdmatch.captures[1]] = ts
                point += ncodeunits(tstext)
            else
                return nothing
            end
        elseif any(.!(isnothing.(values(plan))))
            rest = match(r"^[ \t]*(?:\n|$)", view(content, point:clen))
            return if !isnothing(rest)
                (view(content, 1:point-1+ncodeunits(rest.match)),
                 Planning(plan["DEADLINE"], plan["SCHEDULED"], plan["CLOSED"]))
            end
        else
            return nothing
        end
    end
end

@inline orgmatcher(::Type{Comment}) = r"^([ \t]*#(?:\n| [^\n]*)(?:\n[ \t]*#(?:\n| [^\n]*))*)(?:\n|$)"
@inline orgmatcher(::Type{FixedWidth}) = r"^([ \t]*:(?:\n| [^\n]*)(?:\n[ \t]*:(?:\n| [^\n]*))*)(?:\n|$)"
@inline orgmatcher(::Type{HorizontalRule}) = r"^[ \t]*-{5,}[ \t]*(?:\n|$)"
@inline orgmatcher(::Type{Keyword}) = r"^[ \t]*#\+(\S+): ?(.*)\n?"
@inline orgmatcher(::Type{LaTeXEnvironment}) = r"^[ \t]*\\begin{([A-Za-z*]*)}\n(.*)\n[ \t]*\\end{\1}(?:\n|$)"
@inline orgmatcher(::Type{NodeProperty}) = r"^[ \t]*:([^\+\n]+)(\+)?:(?:[ \t]+([^\n]*)|[ \t]*)?(?:\n|$)"
@inline orgmatcher(::Type{Paragraph}) = r"^[ \t]*+((?!\*+ |#\+\S|\[fn:([A-Za-z0-9-_]*)\] |[ \t]*(?:[*\-\+]|[A-Za-z]\.|\d+\.)[ \t]|:([\w\-_]+):(?:\n|$)|\||#\n|# |:\n|: |[ \t]*\-{5,}[ \t]*(?:\n|$)|\\begin\{)[^\n]+(?:\n[ \t]*+(?!\*+ |#\+\S|\[fn:([A-Za-z0-9-_]*)\] |[ \t]*(?:[*\-\+]|[A-Za-z]\.|\d+\.)[ \t]|:([\w\-_]+):(?:\n|$)|\||#\n|# |:\n|: |[ \t]*\-{5,}[ \t]*(?:\n|$)|\\begin\{)[^\n]+)*)(?:\n|$)"
@inline orgmatcher(::Type{TableRow}) = r"^[ \t]*(\|[^\n]*)(?:\n|$)"
@inline orgmatcher(::Type{TableHrule}) = r"^|[\-\+]+|"
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

@inline orgmatcher(::Type{LineBreak}) = r"^\\\\[ \t]*(?:\n *|$)"
@inline orgmatcher(::Type{Link}) = r"^\[\[([^]]+)\](?:\[([^]]+)\])?\]"
@inline orgmatcher(::Type{Macro}) = r"^{{{([A-Za-z][A-Za-z0-9-_]*)\((.*)\)}}}"
@inline orgmatcher(::Type{RadioTarget}) = r"^<<<(.*?)>>>"
@inline orgmatcher(::Type{Target}) = r"^<<(.*?)>>"
@inline orgmatcher(::Type{StatisticsCookie}) = r"^\[([\d.]*%)\]|^\[(\d+)?\/(\d+)?\]"
@inline orgmatcher(::Type{Script}) = r"^(\S)([_^])({.*}|[+-]?[A-Za-z0-9-\\.]*[A-Za-z0-9])"
@inline orgmatcher(::Type{TableCell}) = r"^|[^|\n]+|"

@inline orgmatcher(::Type{TimestampActive}) = r"<\d{4}-\d\d-\d\d(?: \d?\d:\d\d)?(?: [A-Za-z]{3,7})?>"
@inline orgmatcher(::Type{TimestampInactive}) = r"\[\d{4}-\d\d-\d\d(?: \d?\d:\d\d)?(?: [A-Za-z]{3,7})?\]"
orgmatcher(::Type{Timestamp}) = function(contents::AbstractString)
    rodtypes = Dict("+" => :cumulative,
                    "++" => :catchup,
                    ".+" => :restart,
                    "-" => :warningall,
                    "--" => :warningfirst)
    function parsenum(s)
        n = tryparse(Int, s)
        if !isnothing(n); n else parse(Float64, n) end
    end
    function DateTimeRD(type, date, time, mark, value, unit, warnmark, warnvalue, warnunit)
        type(Date(date),
             if isnothing(time) nothing else Time(time) end,
             if isnothing(mark) nothing else
                 TimestampRepeaterOrDelay(rodtypes[mark], parsenum(value), unit[1]) end,
             if isnothing(warnmark) nothing else
                 TimestampRepeaterOrDelay(rodtypes[warnmark], parsenum(warnvalue), warnunit[1]) end)
    end
    fullts = r"^(?:(<)|\[)(\d{4}-\d\d-\d\d)(?: +[A-Za-z]+)?(?: +(\d?\d:\d\d)(?:-(\d?\d:\d\d))?)?(?: +((?:\+|\+\+|\.\+))(\d[\d.]*)([hdwmy]))?(?: +(-|--)(\d[\d.]*)([hdwmy]))? *(?(1)>|\])"
    tsmatch = match(fullts, contents)
    if !isnothing(tsmatch)
        active, date, timea, timeb, mark, value, unit, warnmark, warnvalue, warnunit = tsmatch.captures
        range, type = if isnothing(active)
            (TimestampInactiveRange, TimestampInactive)
        else
            (TimestampActiveRange, TimestampActive)
        end
        tsmatch2 = if isnothing(timeb) && startswith(contents[1+length(tsmatch.match):end], "--")
            match(fullts, contents[3+length(tsmatch.match):end])
        end
        if isnothing(tsmatch2) ||
            !isnothing(tsmatch2.captures[4]) || # time b must not be set
            active !== tsmatch2.captures[1] # active/inactive must match
            if isnothing(timeb)
                (tsmatch.match, DateTimeRD(type, date, timea, mark, value, unit, warnmark, warnvalue, warnunit))
            else
                (tsmatch.match,
                 range(DateTimeRD(type, date, timea, mark, value, unit, warnmark, warnvalue, warnunit),
                       DateTimeRD(type, date, timeb, mark, value, unit, warnmark, warnvalue, warnunit)))
            end
        else
            _, date2, time2a, _, mark2, value2, unit2, warnmark2, warnvalue2, warnunit2 = tsmatch2.captures
            (SubString(tsmatch.match.string, 1 + tsmatch.match.offset,
                       tsmatch.match.offset + tsmatch.match.ncodeunits + 2 + tsmatch2.match.ncodeunits),
             range(DateTimeRD(type, date, timea, mark, value, unit, warnmark, warnvalue, warnunit),
                   DateTimeRD(type, date2, time2a, mark2, value2, unit2, warnmark2, warnvalue2, warnunit2)))
        end
    elseif startswith(contents, "<%%(")
        tsdiaryend = forwardsbalenced(contents, 4; bracketpairs=Dict('(' => ')'),
                                      escapechars=['\\'], quotes=['"'])
        if !isnothing(tsdiaryend) && ncodeunits(contents) > tsdiaryend &&
            contents[tsdiaryend+1] == '>'
            (contents[1:tsdiaryend+1],
             TimestampDiary(contents[4:tsdiaryend]))
        end
    end
end

@inline orgmatcher(::Type{TextMarkup}) = r"^(^|[\n \t\-({'\"])([*\/+_~=])(\S.*?\n?.*?(?<=\S))\2([\n \t\]\-.,;:!?')}\"]|$)" # TODO peek at start of string being applied to, to properly check PRE condition
orgmatcher(::Type{TextPlain}) = function(content::AbstractString)
    alph(c) = c in 'a':'z' || c in 'A':'Z'
    alphnum(c) = alph(c) || c in '0':'9'
    spc(c) = c in (' ', '\t', '\n')
    if ncodeunits(content) == 1
        return content
    end
    # last index/char, current index/char, next index/char
    # using lc = ' ' should ensure type stability without affecting the result
    li, i, ni = 0, 1, nextind(content, 1)
    lc, c, nc = ' ', content[i], content[ni]
    cc = 1 # char count
    clen = lastindex(content)
    while true
        if alphnum(c) || c in (' ', '\t')
        elseif c == '\n' && lc == '\n' # empty line
            return if i > 1 @inbounds @view content[1:li] end
        elseif c in ('+', '-', '*') && lc == '\n' && spc(nc) # list items
            return if i > 1 @inbounds @view content[1:li] end
        elseif c == '|' && lc == '\n'
            return if i > 1 @inbounds @view content[1:li] end
        elseif c == '^' && (nc in ('{', '+', '-') || alphnum(nc)) # superscripts
            return if i > 2 @inbounds @view content[1:prevind(content, li)] end
        elseif c == '_' && !spc(lc) && !spc(nc)
            if 5 < cc && content[prevind(content, li, 3)] == 'c' # inline babel call
                return if cc > 5 @inbounds @view content[1:prevind(content, li, 4)] end
            elseif 4 < cc && content[prevind(content, li, 2)] == 's' # inline src block
                return if cc > 4 @inbounds @view content[1:prevind(content, li, 3)] end
            else # subscript
                return if cc > 2 @inbounds @view content[1:prevind(content, li)] end
            end
        elseif c == '[' && (nc == '[' || nc == 'f' || nc in '0':'9') # links, footnotes & inactive timestamps & statistics cookies
            return if i > 1 @inbounds @view content[1:li] end
        elseif c == '{' && nc == '{' && i+1 < clen && content[nextind(content, ni)] == '{' # macro
            return if i > 1 @inbounds @view content[1:li] end
        elseif c == '@' && nc == '@' # export snippet
            return if i > 1 @inbounds @view content[1:li] end
        elseif c in ('*', '/', '+', '_', '~', '=') && (spc(lc) || lc in ('-', '(', '{', '\'', '"')) && !spc(nc) # markup
            return if cc > 2 @inbounds @view content[1:prevind(content, li)] end
        elseif c == '\\' && !spc(nc) # entities & latex & line break
            return if i > 1 @inbounds @view content[1:li] end
        elseif c == '<' && (nc == '<' || nc in '0':'9') # targets & active timestamps
            return if i > 1 @inbounds @view content[1:li] end
        end
        li, i, ni = i, ni, nextind(content, ni)
        if i < clen
            lc, c, nc = content[li], content[i], content[ni]
            cc += 1
        else
            return content
        end
    end
end
