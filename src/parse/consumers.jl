function consume(component::Type{<:Component}, text::SubString{String})
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
            @warn "$(component) is using a Function matcher, this should be changed to a dedicated consumer" maxlog=1
            matchresult = matcher(text)
            if isnothing(matchresult) || matchresult isa Tuple{Int64, Component}
                matchresult
            else
                @warn "Matcher for $(component) returned an unworkable result type: $(typeof(matchresult))"
                nothing
            end
        end
    end
end

# Some utility functions

"""
    startofline(::Union{String, SubString})::Bool
Return whether the (Sub)String starts with a line,
i.e. is not part-way through a line."""
startofline(::String) = true
function startofline(s::SubString)
    s.offset == 0 && return true
    prevind(s.string, s.offset+1) == s.offset || return false
    i = s.offset
    while i > 0 && s.string[i] in (' ', '\t')
        i -= 1
    end
    s.string[i] == '\n'
end

function ensurelowercase(s::SubString{String})
    if any(c -> c in 'A':'Z', s)
        lowercase(s)
    else
        s
    end
end

# Consume a category of elements

function consume(::Type{Element}, text::SubString{String})
    el = parseorg(text, org_element_matchers, org_element_fallbacks;
                  partial=true, maxobj=1)
    if !isnothing(el)
        (el[1], el[2][1])
    end
end

function consume(::Type{Object}, text::SubString{String})
    obj = parseorg(text, org_object_matchers, org_object_fallbacks;
                   partial=true, maxobj=1)
    if !isnothing(obj)
        (obj[1], obj[2][1])
    end
end

# Some more complicated elements can not simply be matched, and so need
# specific consumers.

# ---------------------
# Elements
# ---------------------

# Greater Elements

function consume(::Type{AffiliatedKeyword}, text::SubString{String})
    function finalise(key, optval, val)
        key = ensurelowercase(key)
        if haskey(org_keyword_translations, key)
            key = org_keyword_translations[key]
        end
        if key in org_parsed_keywords
            !isnothing(optval) && (optval = parseobjects(Keyword, optval))
            !isnothing(val) && (val = parseobjects(Keyword, val))
        end
        key, optval, val
    end
    keymatch = match(r"^[ \t]*#\+([^\s\[\]]+)([:\[])", text)
    if !isnothing(keymatch)
        key::SubString{String}, kendchar::SubString{String} = keymatch.captures
        if kendchar[1] == '[' && ensurelowercase(key) in org_dual_keywords #+key[optval]: val
            optvalend = forwardsbalenced(text, ncodeunits(keymatch.match),
                                         bracketpairs=Dict('[' => ']'))
            if !isnothing(optvalend)
                optval = @inbounds @view text[1+ncodeunits(keymatch.match):prevind(text, optvalend)]
                valmatch = match(r"^:(?:[ \t]+([^\n]*))?\n", @inbounds @view text[1+optvalend:end])
                if !occursin('\n', optval) && !isnothing(valmatch)
                    val = if !isnothing(valmatch.captures[1])
                        valmatch.captures[1]
                    end
                    key, optval, val = finalise(key, optval, val)
                    (optvalend + ncodeunits(valmatch.match),
                     AffiliatedKeyword(key, optval, val))
                end
            end
        else #+key: val
            keyval = match(r"^[ \t]*#\+(\S+?):(?:[ \t]+?([^\n]*))?\n", text)
            if !isnothing(keyval)
                key, val = keyval.captures
                key, _, val = finalise(key, nothing, val)
                (ncodeunits(keyval.match),
                 AffiliatedKeyword(key, nothing, val))
            end
        end
    end
end

function consume(::Type{AffiliatedKeywordsWrapper}, text::SubString{String})
    affiliatedkeywords = AffiliatedKeyword[]
    point = 1
    textend = lastindex(text)
    nextkw = consume(AffiliatedKeyword, @inbounds @view text[point:textend])
    while !isnothing(nextkw) &&
        (nextkw[2].key in org_affilated_keywords ||
         startswith(nextkw[2].key, "attr_"))
        nextkw::Tuple{Int64, AffiliatedKeyword}
        if occursin(r"^[ \t\r]*\n", @inbounds @view text[point+nextkw[1]:textend])
            return nothing
        end
        push!(affiliatedkeywords, nextkw[2])
        point += nextkw[1]
        nextkw = consume(AffiliatedKeyword, @inbounds @view text[point:textend])
    end
    if length(affiliatedkeywords) > 0
        element = parseorg((@inbounds @view text[point:textend]),
                           org_element_matchers, org_element_fallbacks[1:end-1],
                           partial = true, maxobj = 1)
        if !isnothing(element) && !isempty(last(element)) && any(isa.(Ref(element[2][1]), org_affiliable_elements))
            (point - 1 + element[1],
                AffiliatedKeywordsWrapper(element[2][1], affiliatedkeywords))
        end
    end
end

const org_footnote_element_matchers =
    filter(p -> !isempty(p.second),
           Dict{Char, Vector{<:Type}}(key => filter(v -> v != FootnoteDefinition, value)
                                      for (key, value) in org_element_matchers))

function consume(::Type{FootnoteDefinition}, text::SubString{String})
    labelfn = match(r"^\[fn:([A-Za-z0-9\-_]+)\][ \t]*\n?", text)
    if !isnothing(labelfn)
        fnend, contents = parseorg((@inbounds @view text[1+ncodeunits(labelfn.match):end]),
                                   org_footnote_element_matchers, org_element_fallbacks[1:end-1];
                                   partial=true)
        (ncodeunits(labelfn.match) + fnend,
         FootnoteDefinition(labelfn.captures[1]::SubString{String}, contents))
    end
end

function consume(::Type{InlineTask}, text::SubString{String})
    inlinetaskmatch = match(r"^\*{15,} [^\n]*\n(?:(?!\*+ )[^\n]+\n*)+(\*{15,} +END(?:[ \t\r]*\n|$))?", text)
    if !isnothing(inlinetaskmatch)
        endtask::SubString{String} = inlinetaskmatch.captures[1]
        heading = consume(Heading,
                          @inbounds @view text[1:(ncodeunits(inlinetaskmatch.match) -
                              if !isnothing(endtask); ncodeunits(endtask) else 0 end)])
        if !isnothing(heading)
            heading::Tuple{Int64, Heading}
            (ncodeunits(inlinetaskmatch.match),
             InlineTask(heading[2]))
        end
    end
end

const org_item_element_matchers =
    filter(p -> !isempty(p.second),
           Dict{Char, Vector{<:Type}}(key => filter(v -> v !== List, value)
                                      for (key, value) in org_element_matchers))

function consume(::Type{Item}, text::SubString{String})
    function itemconsume(text, indent)
        indentedlines = let lastindentedpos = something(findfirst('\n', text), ncodeunits(text))
            rest = @inbounds @view text[lastindentedpos+1:end]
            while startswith(rest, indent * "  ")
                lastindentedpos += something(findfirst('\n', rest), ncodeunits(rest))
                rest = @inbounds @view text[lastindentedpos+1:end]
            end
            @inbounds @view text[1:prevind(text, lastindentedpos+1)]
        end
        something(consume(Paragraph, indentedlines), # paragraphs must be entirely indented
                  parseorg(text, org_item_element_matchers, [List],
                           partial=true, maxobj=1) |>
                               o -> if !isempty(o[2])
                                   (o[1], o[2][1])
                               else (o[1], nothing) end)
    end
    itemstart = match(r"^([ \t]*)(\+|\-| \*|(?:[A-Za-z]|[0-9]+)[\.\)]) ", text)
    if !isnothing(itemstart)
        indent::SubString{String}, bullet::SubString{String} = itemstart.captures
        if bullet == "*"
            indent *= " "
        end
        itemextras = match(r"^(?:[ \t]+\[\@([A-Za-z]|[0-9]+)\])?(?:[ \t]+\[([ \-X])\])?(?:[ \t]+([^\n]+?)[ \t]::)?[ \t]+",
                           @inbounds @view text[ncodeunits(itemstart.match):end])
        counterset, checkbox, tag = itemextras.captures
        # collect contents
        rest = @inbounds @view text[ncodeunits(itemstart.match) + ncodeunits(itemextras.match):end]
        contentlen, contentobjs = 0, Component[]
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
        trailingspace = match(r"^(?:[ \t\r]*\n)+", rest)
        if !isnothing(trailingspace)
            contentlen += ncodeunits(trailingspace.match)
        end
        (contentlen + ncodeunits(itemstart.match) + ncodeunits(itemextras.match) - 1,
         Item(bullet, counterset, if !isnothing(checkbox) checkbox[1] end,
              if !isnothing(tag) parseobjects(Item, tag) end, contentobjs))
    end
end

function itemtype(item::Item)
        if !isnothing(item.tag)
            DescriptiveList
        elseif item.bullet in ("+", "-", "*")
            UnorderedList
        else
            OrderedList
        end
end

function consume(::Type{List}, text::SubString{String})
    itemstart = match(r"^([ \t]*)(\+|\-| \*|(?:[A-Za-z]|[0-9]+)[\.\)]) ", text)
    if !isnothing(itemstart)
        nextitem = consume(Item, text)
        if !isnothing(nextitem)
            nextitem::Tuple{Int64, Item}
            listindent::SubString{String} = itemstart.captures[1]
            point = 1
            items = Item[]
            listtype = itemtype(nextitem[2])
            while !isnothing(nextitem) && point < ncodeunits(text)
                len, item = nextitem
                (itemtype(item) != listtype) && break
                point += len
                push!(items, item)
                rest = @inbounds @view text[point:end]
                nextitem = if startswith(rest, listindent)
                    consume(Item, rest)
                end
            end
        point-1, listtype(items)
        end
    end
end

# Leser Elements

function consume(::Type{Clock}, text::SubString{String})
    clockmatch = match(r"^[ \t]*clock:[ \t]+(\[[^\n]*?)[ \t\r]*(?:\n(?:[ \t\r]*\n)*|$)"i, text)
    if !isnothing(clockmatch)
        rest::SubString{String} = clockmatch.captures[1]
        timestamp = consume(Timestamp, rest)
        if !isnothing(timestamp)
            tslen::Int64, ts::Timestamp = timestamp
            if ts isa TimestampInactive && tslen == ncodeunits(rest)
                (ncodeunits(clockmatch.match),
                    Clock(ts, nothing))
            elseif ts isa TimestampInactiveRange
                durationmatch = match(r"^[ \t]+=>[ \t]+(\d+):(\d\d)$",
                                      @inbounds @view rest[1+tslen:end])
                if !isnothing(durationmatch)
                    hours::SubString{String}, mins::SubString{String} = durationmatch.captures
                    (ncodeunits(clockmatch.match),
                     Clock(ts, (parse(Int, hours), parse(Int, mins))))
                end
            end
        end
    end
end

function consume(::Type{Planning}, text::SubString{String})
    plan = Dict{String, Union{Nothing, Timestamp}}(
        "DEADLINE" => nothing,
        "SCHEDULED" => nothing,
        "CLOSED" => nothing)
    point = 1
    clen = lastindex(text)
    while point <= clen+1
        kwdmatch = match(r"^[ \t]*(DEADLINE|SCHEDULED|CLOSED):[ \t]*", view(text, point:clen))
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

function consume(::Type{ParagraphForced}, text::SubString{String})
    line = text[1:something(findfirst('\n', text), end+1)-1]
    location = if text isa SubString
        let char=1+length(text.string[1:text.offset])
            linenum=1+count(==('\n'), text.string[1:text.offset])
            column=length(text.string[1+something(findprev('\n', text.string, text.offset), 0):1+text.offset])
        "\n(line $linenum, column $column, char $char)"
            end
        else
        ""
        end
    @warn "The following line is being coerced to a paragraph:

$line$location

This is unusual, and likely caused by a malformed Org document."
    rest = @inbounds @view text[1+length(line):end]
    trailingspace = match(r"^[ \t\r\n]+", rest)
    blanklength = if !isnothing(trailingspace)
        ncodeunits(trailingspace.match)
    else
        0
    end
    ncodeunits(line)+blanklength, Paragraph(parseobjects(Paragraph, line))
end

# ---------------------
# Objects
# ---------------------

function consume(::Type{Entity}, text::SubString{String})
    # TODO work out how to properly handle \entitity{}
    # maybe this should be handled at the render stage?
    entitymatch = match(r"^\\([A-Za-z]+)(?:{}|[^A-Za-z]|$)", text)
    if !isnothing(entitymatch)
        name::SubString{String} = entitymatch.captures[1]
        if name in keys(Entities)
            1+ncodeunits(name), Entity(name)
        end
    end
end

function consume(::Type{Citation}, text::SubString{String})
    if startswith(text, "[cite") && ncodeunits(text) >= 8
        citeend = forwardsbalenced(text, 1, bracketpairs=Dict('[' => ']'))
        if !isnothing(citeend)
            citeinner = @inbounds @view text[6:citeend-1]
            @assert occursin(':', citeinner)
            styles, body = split(citeinner, ':', limit=2)
            stylematch = match(r"^(?:\/([A-Za-z0-9\-_]+)(?:\/([A-Za-z0-9\-_\/]+))?)?$", styles)
            if !isnothing(stylematch) && !isnothing(match(r"@[\w\-\.:?!`'\/*@+|(){}<>&_^$#^~]", body))
                style, substyle = stylematch.captures
                citerefs = map(split(body, ';')) do keycite
                    keymatch = match(r"^(.+?)?@([\w\-\.:?!`'\/*@+|(){}<>&_^$#^~]+)(.+)?$", keycite)
                    if isnothing(keymatch)
                        keycite
                    else
                        prefixstr, key, suffixstr = keymatch.captures
                        prefix = if isnothing(prefixstr)
                            Object[]
                        else
                            parseobjects(CitationReference, prefixstr)
                        end
                        suffix = if isnothing(suffixstr)
                            Object[]
                        else
                            parseobjects(CitationReference, suffixstr)
                        end
                        CitationReference(prefix, key, suffix)
                    end
                end
                globalprefix = if !isa(citerefs[1], CitationReference)
                    parseobjects(CitationReference, popfirst!(citerefs))
                else
                    Object[]
                end
                globalsuffix = if !isa(citerefs[end], CitationReference)
                    parseobjects(CitationReference, pop!(citerefs))
                else
                    Object[]
                end
                (citeend,
                 Citation((style, substyle), globalprefix, citerefs, globalsuffix))
            end
        end
    end
end

function consume(::Type{FootnoteReference}, text::SubString{String})
    if startswith(text, "[fn:") && ncodeunits(text) >= 6 && text[5] != ']'
        labelfn = match(r"^\[fn:([A-Za-z0-9\-_]+)(\]|:)", text)
        if !isnothing(labelfn) && !startofline(text) && labelfn.captures[2] == "]"
            (ncodeunits(labelfn.match), FootnoteReference(labelfn.captures[1], nothing))
        else
            label = if text[5] == ':'
                Some(nothing)
            elseif labelfn.captures[2] == ":"
                labelfn.captures[1]
            end
            defend = forwardsbalenced(text, 1, bracketpairs=Dict('[' => ']'))
            if !isnothing(label) && !isnothing(defend)
                labellen = if isnothing(something(label)) 0 else ncodeunits(label) end
                definition = parseobjects(FootnoteReference,
                                          @inbounds view(text, 6+labellen:defend-1))
                (defend, FootnoteReference(something(label), definition))
            end
        end
    end
end

function consume(::Type{InlineSourceBlock}, text::SubString{String})
    srcmatch = match(r"^src_(\S+?)(?:\[([^\n]+)\])?{", text)
    if !isnothing(srcmatch)
        codeend = forwardsbalenced(text, ncodeunits(srcmatch.match),
                                   bracketpairs=Dict('{' => '}'),
                                   escapechars=['\\'], quotes=['"'])
        if !isnothing(codeend)
            lang::SubString{String}, options = srcmatch.captures
            code = @inbounds @view text[1+ncodeunits(srcmatch.match):codeend-1]
            codeend, InlineSourceBlock(lang, options, code)
        end
    end
end

function consume(::Type{RegularLink}, text::SubString{String})
    path = match(r"^\[\[((?:[^\]\[\\]+|\\(?:\\\\)*[\[\]]|\\+[^\]\[])+)\]", text)
    if !isnothing(path) && ncodeunits(path.match) < ncodeunits(text)
        linkpath = parse(LinkPath, path.captures[1]::SubString{String})
        matchoffset = 1+ncodeunits(path.match)
        if text[matchoffset] == ']'
            (1 + matchoffset,
             RegularLink(linkpath, nothing))
        else
            descriptionend = forwardsbalenced(text, matchoffset, bracketpairs=Dict('[' => ']'))
            if !isnothing(descriptionend)
                (1 + descriptionend,
                RegularLink(linkpath,
                            parseobjects(RegularLink,
                                         @inbounds @view text[1+matchoffset:prevind(text, descriptionend)])))
            end
        end
    end
end

function consume(::Type{Timestamp}, text::SubString{String})
    rodtypes = Dict("+" => :cumulative,
                    "++" => :catchup,
                    ".+" => :restart,
                    "-" => :warningall,
                    "--" => :warningfirst)
    function parsenum(s::SubString{String})
        n = tryparse(Int, s)
        if !isnothing(n); n else parse(Float64, n) end
    end
    function DateTimeRD(type, date, time, mark, value, unit, warnmark, warnvalue, warnunit)
        type(if isnothing(time) || !isnothing(tryparse(Time, time))
                 parse(Date, date)
             else
                 date = parse(Date, date)
                 hour, min = parse.(Int, match(r"(\d?\d):(\d\d)", time).captures)
                 date += Day(hour ÷ 24)
                 time = Time(hour % 24, min)
                 date
             end,
             if isnothing(time) nothing elseif time isa Time time else Time(time) end,
             if isnothing(mark) nothing else
                 TimestampRepeaterOrDelay(rodtypes[mark], parsenum(value), unit[1]) end,
             if isnothing(warnmark) nothing else
                 TimestampRepeaterOrDelay(rodtypes[warnmark], parsenum(warnvalue), warnunit[1]) end)
    end
    fullts = r"^(?:(<)|\[)(\d{4}-\d\d-\d\d)(?: +[A-Za-z]+)?(?: +(\d?\d:\d\d)(?:-(\d?\d:\d\d))?)?(?: +((?:\+|\+\+|\.\+))(\d[\d.]*)([hdwmy]))?(?: +(-|--)(\d[\d.]*)([hdwmy]))? *(?(1)>|\])"
    tsmatch = match(fullts, text)
    if !isnothing(tsmatch)
        active, date::SubString{String}, timea, timeb, mark, value, unit, warnmark, warnvalue, warnunit = tsmatch.captures
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
            _, date2::SubString{String}, time2a, _, mark2, value2, unit2, warnmark2, warnvalue2, warnunit2 = tsmatch2.captures
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

function consume(T::Type{<:Timestamp}, text::SubString{String})
    ts = consume(Timestamp, text)
    if !isnothing(ts)
        @parseassert(T, ts isa T, "\"$text\" is a $(typeof(ts))")
        ts
    end
end

function consume(::Type{TextMarkup}, text::SubString{String})
    if text[1] in ('*', '/', '_', '=', '~', '+') &&
        if text isa SubString
            text.offset == 0 ||
            text.string[prevind(text.string, 1+text.offset)] in
            ('-', '(', '{', ''', '"', ' ', '\t', '\n', '\u2000':'\u200c'...) || # pre condition
            (text.string[prevind(text.string, 1+text.offset)] == '[' &&
            text.string[prevind(text.string, text.offset)] == ']') # link description
        else
            true
        end
        markupmatch = match(r"^([*\/_=~+])(\S[^\n]*?(?:\n[^\n]+?(?:\n[^\n]+?)?)?(?<=\S))\1([ \t\n\u2000-\u200c\-.,;:!?'\")\[}]|$)", text)
        if !isnothing(markupmatch)
            char::SubString{String}, content::SubString{String}, _ = markupmatch.captures
            formatting = org_markup_formatting[char[1]]
            parsedcontent = if formatting in (:verbatim, :code)
                content
            else
                parseobjects(TextMarkup, content)
            end
            (2 + ncodeunits(content),
             TextMarkup(formatting, parsedcontent))
        end
    end
end

function consume(::Type{TextPlain}, content::SubString{String})
    alph(c) = c in 'a':'z' || c in 'A':'Z'
    alphnum(c) = alph(c) || c in '0':'9'
    hspc(c) = c in (' ', '\t', '\u2000':'\u200c'...)
    spc(c) = hspc(c) || c == '\n'
    regularisewhitespace(s) = replace(s, r"[ \t\n]{2,}|\n" => " ")
    function textobjupto(index)
        substr = @inbounds @view content[1:index]
        if index > 0
        (ncodeunits(substr),
         TextPlain(if occursin('\n', substr) || occursin("  ", substr)
                       replace(substr, r"[ \t\n]{2,}|\n" => " ")
                   else
                       substr
                   end))
        end
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
        if alphnum(c) || hspc(c)
        elseif c == '\n' && lc == '\n' # empty line
            return if i > 1 textobjupto(li) end
        elseif c in ('+', '-', '*') && lc == '\n' && spc(nc) # list items, heading
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
        elseif c == ':' && !hspc(lc) # plain link
            return if i > 1 textobjupto(something(findprev(c -> !(alphnum(c) || c in ('_', '-', '/', '+', '\'', '"')),
                                                           content, li), li)) end
        elseif c == '[' && (nc == '[' || nc == 'f' || nc == 'c' || nc in '0':'9') # regular link, citations, footnotes & inactive timestamps & statistics cookies
            return if i > 1 textobjupto(li) end
        elseif c == '{' && nc == '{' && i+1 < clen && content[nextind(content, ni)] == '{' # macro
            return if i > 1 textobjupto(li) end
        elseif c == '@' && nc == '@' # export snippet
            return if i > 1 textobjupto(li) end
        elseif c in ('*', '/', '+', '_', '~', '=') && (spc(lc) || lc in ('-', '(', '{', '\'', '"')) && !spc(nc) # markup
            return if cc > 2 textobjupto(li) end
        elseif c == '\\' && !spc(nc) # entities & latex & line break
            return if i > 1 textobjupto(li) end
        elseif c == '<' # angle links, targets, active timestamps
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

function consume(::Type{TextPlainForced}, s::SubString{String})
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
        (ncodeunits(c), TextPlain(c))
    end
end
