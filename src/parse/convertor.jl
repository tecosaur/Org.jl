macro org_str(content::String)
    content # TODO
end

function parseinlineorg(content::AbstractString, debug=false)
    objects = OrgComponent[]
    point = 1
    @parseassert(Paragraph, !occursin("\n\n", content),
                 "cannot contain a double newline")
    function consume(matcher::Regex, parser, text)
        test = match(Regex("^(?:" * matcher.pattern * ")"), text)
        if !isnothing(test)
            push!(objects, parser(test.match))
            point += length(test.match)
        end
    end
    function consume(matcher::Function, parser, text)
        res = matcher(text)
        if !isnothing(res)
            obj = parser(res)
            if length(objects) > 0 &&
                objects[end] isa TextPlain  &&
                obj isa TextPlain
                objects[end] *= obj
            else
                push!(objects, obj)
            end
            point += length(res)
        end
    end
    matchers = [(gobbletextplain, TextPlain),
                (LineBreakRegex, (_) -> LineBreak()),
                # OrgEntity
                (LaTeXFragmentRegex, LaTeXFragment),
                (InlineBabelCallRegex, InlineBabelCall),
                (ExportSnippetRegex, ExportSnippet),
                # InlineSrcBlock
                # FootnoteRef
                (LinkRegex, Link),
                (MacroRegex, Macro),
                (RadioTargetRegex, RadioTarget),
                (TargetRegex, Target),
                (StatisticsCookieRegex, StatisticsCookie),
                (ScriptRegex, Script),
                # Timestamp
                (TextMarkupRegex, TextMarkup),
                (s -> s[1:1], TextPlain)]
    points = [point]
    while point < length(content)
        if debug print("\n\e[36m$(lpad(point, 4))\e[37m") end
        for (matcher, parser) in matchers
            res = consume(matcher, parser, @view content[point:end])
            isnothing(res) || break
        end
        push!(points, point)
        if debug
            print(rpad(" ─[\e[33m$(typeof(objects[end]))\e[37m" *
                "(\e[35m$(length(objects))\e[37m)]─", 42, '─'),
                  "> \e[36m$(lpad(point, 4))\e[37m",
                  "  \e[32m'", content[points[end-1]:points[end]-1], "'\e[37m")
        end
    end
    if debug print("\n\n") end
    objects
end

bracketpairs = Dict('(' => ')',
                    '[' => ']',
                    '{' => '}')
# TODO handle quotes
function forwardsbalenced(content::AbstractString, point::Integer=1, limit::Integer=length(content))
    open = content[point]
    if !(open in keys(bracketpairs))
        throw(ErrorException("index $point does not lie on a recognised open bracket: $(join(keys(bracketpairs), ", "))"))
    end
    close = bracketpairs[open]
    depth = 1
    while point < limit
        point += 1
        if content[point] == open
            depth += 1
        elseif content[point] == close
            depth -= 1
        end
        if depth == 0
            return point
        end
    end
    throw(ErrorException("hit index limit $limit before finding paired bracket"))
end
