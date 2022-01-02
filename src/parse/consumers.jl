function consume(component::Type{<:OrgComponent}, text::AbstractString)
    matcher = orgmatcher(component)
    if isnothing(matcher)
        @warn "No matcher is defined for $(component), should it have a matcher or dedicated consumer?" maxlog=1
        nothing
    else
        if matcher isa Regex
            rxmatch = match(matcher, text)
            if !isnothing(rxmatch)
                (ncodeunits(rxmatch.match), component(rxmatch.captures))
            end
        elseif matcher isa Function
            matchresult = matcher(text)
            if isnothing(matchresult) || matchresult isa Tuple{Int64, OrgComponent}
                matchresult
            else
                @warn "Matcher for $(component) returned an unworkable result type: $(typeof(matchresult))"
                nothing
            end
        end
    end
end

# Some more complicated elements can not simply be matched, and so need
# specific consumers.

const OrgItemElementMatchers =
    filter(p -> !isempty(p.second),
           Dict{Char, Vector{<:Type}}(key => filter(v -> v !== List, value)
                                      for (key, value) in OrgElementMatchers))

function consume(::Type{Item}, text::AbstractString)
    function itemconsume(text, indent)
        indentedlines = let lastindentedpos = something(findfirst('\n', text), ncodeunits(text))
            rest = @inbounds @view text[lastindentedpos+1:end]
            while startswith(rest, indent * "  ")
                lastindentedpos += something(findfirst('\n', rest), ncodeunits(rest))
                rest = @inbounds @view text[lastindentedpos+1:end]
            end
            @inbounds @view text[1:lastindentedpos]
        end
        something(consume(Paragraph, indentedlines), # paragraphs must be entirely indented
                  parseorg(text, OrgItemElementMatchers, [List],
                           partial=true, maxobj=1) |>
                               o -> if !isempty(o[2])
                                   (o[1], o[2][1])
                               else (o[1], nothing) end)
    end
    itemstart = match(r"^([ \t]*)(\+|\-| \*|(?:[A-Za-z]|[0-9]+)[\.\)]) ", text)
    if !isnothing(itemstart)
        indent, bullet = itemstart.captures
        if bullet == "*"
            indent *= " "
        end
        itemextras = match(r"^(?:[ \t]+\[\@([A-Za-z]|[0-9]+)\])?(?:[ \t]+\[([ \-X])\])?(?:[ \t]+([^\n]+)::)?[ \t]+",
                           @inbounds @view text[ncodeunits(itemstart.match):end])
        counterset, checkbox, tag = itemextras.captures
        # collect contents
        rest = @inbounds @view text[ncodeunits(itemstart.match) + ncodeunits(itemextras.match):end]
        contentlen, contentobjs = 0, OrgComponent[]
        len, obj = itemconsume(rest, indent)
        contentlen += len
        push!(contentobjs, obj)
        rest = @inbounds @view text[contentlen + ncodeunits(itemstart.match) + ncodeunits(itemextras.match):end]
        while startswith(rest, indent * "  ") && !isnothing(obj)
            len, obj = itemconsume(rest, indent)
            contentlen += len
            push!(contentobjs, obj)
            rest = @inbounds @view text[contentlen + ncodeunits(itemstart.match) + ncodeunits(itemextras.match):end]
        end
        (contentlen + ncodeunits(itemstart.match) + ncodeunits(itemextras.match) - 1,
         Item(bullet, counterset, if !isnothing(checkbox) checkbox[1] end,
              tag, contentobjs))
    end
end

function consume(::Type{List}, text::AbstractString)
    itemstart = match(r"^([ \t]*)(\+|\-| \*|(?:[A-Za-z]|[0-9]+)[\.\)]) ", text)
    if !isnothing(itemstart)
        point = 1
        items = Item[]
        nextitem = consume(Item, text)
        while !isnothing(nextitem) && point < ncodeunits(text)
            len, item = nextitem
            point += len
            push!(items, item)
            nextitem = consume(Item, @inbounds @view text[point:end])
        end
        if items[1].bullet in ("+", "-", "*")
            point-1, UnorderedList(items)
        else
            point-1, OrderedList(items)
        end
    end
end

function consume(::Type{Planning}, text::AbstractString)
    plan = Dict{String, Union{Nothing, Timestamp}}(
        "DEADLINE" => nothing,
        "SCHEDULED" => nothing,
        "CLOSED" => nothing)
    point = 1
    clen = ncodeunits(text)
    while point <= clen+1
        kwdmatch = match(r"^[ \t]*(DEADLINE|SCEDULED|CLOSED):[ \t]*", view(text, point:clen))
        if !isnothing(kwdmatch)
            point += ncodeunits(kwdmatch.match)
            tsmatch = consume(Timestamp, view(text, point:clen))
            if !isnothing(tsmatch)
                tslen, ts = tsmatch
                plan[kwdmatch.captures[1]] = ts
                point += tslen
            else
                return nothing
            end
        elseif any(.!(isnothing.(values(plan))))
            rest = match(r"^[ \t]*(?:\n|$)", view(text, point:clen))
            return if !isnothing(rest)
                (point + ncodeunits(rest.match),
                 Planning(plan["DEADLINE"], plan["SCHEDULED"], plan["CLOSED"]))
            end
        else
            return nothing
        end
    end
end

function consume(::Type{Entity}, text::AbstractString)
    entitymatch = match(r"^\\([A-Za-z]*)({}|[^A-Za-z]|$)", text)
    if !isnothing(entitymatch)
        name, post = entitymatch.captures
        if name in keys(Entities)
            ncodeunits(entitymatch.match), Entity(name, post)
        end
    end
end

function consume(::Type{InlineSourceBlock}, text::AbstractString)
    srcmatch = match(r"^src_(\S+?)(?:\[([^\n]+)\])?{", text)
    if !isnothing(srcmatch)
        codeend = forwardsbalenced(text, ncodeunits(srcmatch.match),
                                   bracketpairs=Dict('{' => '}'),
                                   escapechars=['\\'], quotes=['"'])
        if !isnothing(codeend)
            lang, options = srcmatch.captures
            code = @inbounds @view text[1+ncodeunits(srcmatch.match):codeend-1]
            codeend, InlineSourceBlock(lang, options, code)
        end
    end
end

function consume(::Type{Timestamp}, text::AbstractString)
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
    tsmatch = match(fullts, text)
    if !isnothing(tsmatch)
        active, date, timea, timeb, mark, value, unit, warnmark, warnvalue, warnunit = tsmatch.captures
        range, type = if isnothing(active)
            (TimestampInactiveRange, TimestampInactive)
        else
            (TimestampActiveRange, TimestampActive)
        end
        tsmatch2 = if isnothing(timeb) && startswith(text[1+length(tsmatch.match):end], "--")
            match(fullts, text[3+length(tsmatch.match):end])
        end
        if isnothing(tsmatch2) ||
            !isnothing(tsmatch2.captures[4]) || # time b must not be set
            active !== tsmatch2.captures[1] # active/inactive must match
            if isnothing(timeb)
                (ncodeunits(tsmatch.match),
                 DateTimeRD(type, date, timea, mark, value, unit, warnmark, warnvalue, warnunit))
            else
                (ncodeunits(tsmatch.match),
                 range(DateTimeRD(type, date, timea, mark, value, unit, warnmark, warnvalue, warnunit),
                       DateTimeRD(type, date, timeb, mark, value, unit, warnmark, warnvalue, warnunit)))
            end
        else
            _, date2, time2a, _, mark2, value2, unit2, warnmark2, warnvalue2, warnunit2 = tsmatch2.captures
            (tsmatch.match.ncodeunits + 1 + tsmatch2.match.ncodeunits,
             range(DateTimeRD(type, date, timea, mark, value, unit, warnmark, warnvalue, warnunit),
                   DateTimeRD(type, date2, time2a, mark2, value2, unit2, warnmark2, warnvalue2, warnunit2)))
        end
    elseif startswith(text, "<%%(")
        tsdiaryend = forwardsbalenced(text, 4; bracketpairs=Dict('(' => ')'),
                                      escapechars=['\\'], quotes=['"'])
        if !isnothing(tsdiaryend) && ncodeunits(text) > tsdiaryend &&
            text[tsdiaryend+1] == '>'
            (tsdiaryend, TimestampDiary(text[4:tsdiaryend]))
        end
    end
end

function consume(T::Type{<:Timestamp}, text::AbstractString)
    ts = consume(Timestamp, text)
    if !isnothing(ts)
        @parseassert(T, ts isa T, "\"$text\" is a $(typeof(ts))")
        ts
    end
end

function consume(::Type{TextPlain}, content::AbstractString)
    alph(c) = c in 'a':'z' || c in 'A':'Z'
    alphnum(c) = alph(c) || c in '0':'9'
    spc(c) = c in (' ', '\t', '\n')
    regularisewhitespace(s) = replace(s, r"[ \t\n]{2,}|\n" => " ")
    function textobjupto(index)
        substr = @inbounds @view content[1:index]
        (ncodeunits(substr),
         TextPlain(if occursin('\n', substr) || occursin("  ", substr)
                       replace(substr, r"[ \t\n]{2,}|\n" => " ")
                   else
                       substr
                   end))
    end
    clen = lastindex(content)
    if clen == 1
        return (1, TextPlain(content))
    end
    # last index/char, current index/char, next index/char
    # using lc = ' ' should ensure type stability without affecting the result
    li, i, ni = 0, 1, nextind(content, 1)
    lc, c, nc = ' ', content[i], content[ni]
    cc = 1 # char count
    while true
        if alphnum(c) || c in (' ', '\t')
        elseif c == '\n' && lc == '\n' # empty line
            return if i > 1 textobjupto(li) end
        elseif c in ('+', '-', '*') && lc == '\n' && spc(nc) # list items
            return if i > 1 textobjupto(li) end
        elseif c == '|' && lc == '\n'
            return if i > 1 textobjupto(li) end
        elseif c == '^' && (nc in ('{', '+', '-') || alphnum(nc)) # superscripts
            return if i > 2 textobjupto(prevind(content, li)) end
        elseif c == '_' && !spc(lc) && !spc(nc)
            if 5 < cc && content[prevind(content, li, 3)] == 'c' # inline babel call
                return if cc > 5 textobjupto(prevind(content, li, 4)) end
            elseif 4 < cc && content[prevind(content, li, 2)] == 's' # inline src block
                return if cc > 4 textobjupto(prevind(content, li, 3)) end
            else # subscript
                return if cc > 2 textobjupto(prevind(content, li)) end
            end
        elseif c == '[' && (nc == '[' || nc == 'f' || nc in '0':'9') # links, footnotes & inactive timestamps & statistics cookies
            return if i > 1 textobjupto(li) end
        elseif c == '{' && nc == '{' && i+1 < clen && content[nextind(content, ni)] == '{' # macro
            return if i > 1 textobjupto(li) end
        elseif c == '@' && nc == '@' # export snippet
            return if i > 1 textobjupto(li) end
        elseif c in ('*', '/', '+', '_', '~', '=') && (spc(lc) || lc in ('-', '(', '{', '\'', '"')) && !spc(nc) # markup
            return if cc > 2 textobjupto(prevind(content, li)) end
        elseif c == '\\' && !spc(nc) # entities & latex & line break
            return if i > 1 textobjupto(li) end
        elseif c == '<' && (nc == '<' || nc in '0':'9') # targets & active timestamps
            return if i > 1 textobjupto(li) end
        end
        li, i, ni = i, ni, nextind(content, ni)
        if i < clen
            lc, c, nc = content[li], content[i], content[ni]
            cc += 1
        else
            return textobjupto(clen)
        end
    end
end

forcematchwarn = false
function setforcematchwarn(b::Bool)
    global forcematchwarn = b
end

function consume(::Type{TextPlainForce}, s::AbstractString)
    c = SubString(s, 1, 1)
    if forcematchwarn
        printstyled(stderr, "Warning:", bold=true, color=:yellow)
        print(stderr, " Force matching ")
        printstyled(stderr, '\'', if c == '\n' "\\n" else c end, '\'', color=:cyan)
        print(stderr, " from ")
        b = IOBuffer()
        show(b, s[1:min(50,end)])
        printstyled(stderr, String(take!(b)), if length(s) > 50 "…" else "" end, color=:green)
        print(stderr, "\n         This usually indicates a case where the plain text matcher can be improved.\n")
    end
    if c == "\n"
        (1, TextPlain(" "))
    else
        (1, TextPlain(c))
    end
end
