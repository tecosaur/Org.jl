@doc org"""
#+begin_src julia
consume(component::Type{<:OrgComponent}, text::AbstractString)
#+end_src
Try to /consume/ a ~component~ from the start of ~text~.

Returns a tuple of the consumed text and the resulting component
or =nothing= if this is not possible.
"""
function consume(component::Type{<:OrgComponent}, text::AbstractString)
    matcher = orgmatcher(component)
    if !isnothing(component)
        if matcher isa Regex
            rxmatch = match(matcher, text)
            if !isnothing(rxmatch)
                (rxmatch.match, component(rxmatch.captures))
            end
        elseif matcher isa Function
            componenttext = matcher(text)
            if !isnothing(componenttext)
                (componenttext, convert(component, componenttext))
            end
        end
    end
end

abstract type TextPlainForce end
function consume(::Type{TextPlainForce}, s::AbstractString)
    c = SubString(s, 1, 1)
    (c, TextPlain(c))
end

const InlineTypeMatchers =
    Dict('[' => [Link, Timestamp, StatisticsCookie],
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
         'c' => [InlineBabelCall,
                 TextPlain],
         # InlineSrcBlock
         # FootnoteRef
         # Timestamp
         )
const InlineTypeFallbacks =
    [TextPlain,
     Script,
     TextMarkup,
     TextPlainForce] # we *must* move forwards by some ammount, c.f. §4.10


function parseinlineorg(content::AbstractString, debug=false)
    point, objects = 1, OrgComponent[]
    @parseassert(Paragraph, !occursin("\n\n", content),
                 "cannot contain a double newline")
    points = [point]
    clen = length(content) # this does not change, help the compiler
    while point < clen
        if debug print("\n\e[36m$(lpad(point, 4))\e[37m") end
        obj::Union{OrgObject, Nothing} = nothing
        char = content[point]
        if char in keys(InlineTypeMatchers)
            types = InlineTypeMatchers[char]
            for type in types
                # profiling indicates that @view content[point:clen] is about a
                # third faster than @view content[point:end] for large strings
                res = consume(type, @view content[point:clen])
                if !isnothing(res)
                    text, obj = res
                    point += length(text)
                    break
                end
            end
        end
        if isnothing(obj)
            types = InlineTypeFallbacks
            for type in types
                res = consume(type, @view content[point:clen])
                if !isnothing(res)
                    text, obj = res
                    point += length(text)
                    break
                end
            end
        end
        if obj isa TextPlain &&
            length(objects) > 0 &&
            objects[end] isa TextPlain
            objects[end] *= obj
        else
            push!(objects, obj)
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
