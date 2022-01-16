
struct OrgParseError
    content::AbstractString
    point::Integer
    allowedtypes::Vector{<:Type}
end

function Base.showerror(io::IO, ex::OrgParseError)
    beforepoint = if ex.point > 10 "…" else "" end *
        replace(ex.content[max(1, prevind(ex.content, ex.point, 10)):ex.point-1], '\n' => "\\n")
    afterpoint = replace(ex.content[ex.point:min(end, nextind(ex.content, ex.point, 45))], '\n' => "\\n") *
        if ex.point + 45 < length(ex.content) "…" else "" end
    print(io, "Org parse failed at index $(ex.point) (char $(length(ex.content[1:ex.point]))) of string:\n")
    printstyled(io, " ", beforepoint, color=:light_black)
    printstyled(io, "", afterpoint, "\n", color=:yellow)
    printstyled(io, " "^length(beforepoint), " ^", bold=true, color=:red)
    print(io, "\nThe immediate remaining content did not match any of the allowed components:\n")
    print(io, " • ", join(string.(ex.allowedtypes), "\n • "), "\n")
    Base.Experimental.show_error_hints(io, ex)
end

function parseorg(content::AbstractString, typematchers::Dict{Char, <:AbstractVector{<:Type}},
                  typefallbacks::AbstractVector{<:Type};
                  debug::Bool=false, partial::Bool=false, maxobj::Integer=0)
    point, objects = 1, OrgComponent[]
    points = [point]
    clen = lastindex(content) # this does not change, help the compiler
    while point <= clen
        if debug print("\n\e[36m$(lpad(point, 4))\e[37m") end
        obj::Union{OrgComponent, Nothing} = nothing
        types = DataType[]
        # use the next non-whitespace char to guide type matchers
        char = if content[point] == ' ' || content[point] == '\t'
            nextnonspace = findfirst(c -> c != ' ' && c != '\t',
                                     @inbounds @view content[point:clen])
            if !isnothing(nextnonspace)
                content[point + nextnonspace - 1]
            else
                content[point]
            end
        else
            content[point]
        end
        if char in keys(typematchers)
            types = typematchers[char]
            for type in types
                # profiling indicates that @inbounds @view content[point:clen] is about a
                # third faster than @inbounds @view content[point:end] for large strings
                res = consume(type, @inbounds @view content[point:clen])
                if !isnothing(res)
                    width, obj = res
                    point += width
                    break
                end
            end
        end
        if isnothing(obj)
            for type in typefallbacks
                res = consume(type, @inbounds @view content[point:clen])
                if !isnothing(res)
                    width, obj = res
                    point += width
                    break
                end
            end
        end
        if isnothing(obj)
            if partial
                return point-1, objects
            elseif content isa SubString
                throw(OrgParseError(content.string, content.offset + point,
                                    vcat(types, typefallbacks)))
            else
                throw(OrgParseError(content, point, vcat(types, typefallbacks)))
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
                  "> \e[36m$(lpad(point, 4))\e[37m\n",
                  "     \e[32m'", rpad(content[points[end-1]:prevind(content, points[end])] * "'", 28),
                  "\e[37m  ", objects[end])
        end
        if partial && 0 < length(objects) == maxobj
            return point-1, objects
        end
    end
    if debug print("\n\n") end
    if partial
        point-1, objects
    else
        objects
    end
end

function parseorg(content::AbstractString, typefallbacks::AbstractVector{<:Type};
                  debug=false, partial=false)
    parseorg(content, Dict{Char, Vector{DataType}}(),
             typefallbacks; debug, partial)
end

# Parsing objects, with restrictions

filtermatcher(allowed::Vector{<:Type}, matchers=org_object_matchers) =
    filter(p -> !isempty(p.second),
           Dict{Char, Vector{<:Type}}(key => filter(v -> v ∈ allowed, value)
                                      for (key, value) in matchers))

const org_object_resticted_matchers =
    Dict(o => filtermatcher(org_object_restrictions[o])
         for o in keys(org_object_restrictions))

const org_object_resticted_fallbacks =
    Dict(o => [org_object_fallbacks ∩ org_object_restrictions[o]; TextPlainForced]
         for o in keys(org_object_restrictions))

function parseobjects(context::Type, content::AbstractString; debug=false, partial=false)
    @assert context in keys(org_object_restrictions)
    Vector{Object}(
        parseorg(content, org_object_resticted_matchers[context],
                 org_object_resticted_fallbacks[context]; debug, partial))
end

# parsing utilities

function forwardsbalenced(content::AbstractString, point::Integer=1, limit::Integer=lastindex(content);
                          bracketpairs::Dict{Char, Char}=Dict{Char, Char}(), escapechars::Vector{Char}=Char[],
                          quotes::Vector{Char}=Char[], spacedquotes::Vector{Char}=Char[])
    open = content[point]
    if !(open in keys(bracketpairs))
        throw(ErrorException("index $point does not lie on a recognised open bracket: $(join(keys(bracketpairs), ", "))"))
    end
    close = bracketpairs[open]
    currentquote = nothing
    depth = 1
    while point < limit
        point = nextind(content, point)
        # escaped chars
        if content[point] in escapechars &&
            point < limit
            point += 1
            continue
        end
        # unquote
        if !isnothing(currentquote)
            if content[point] == currentquote
                if currentquote in quotes
                    currentquote = nothing
                    continue
                elseif currentquote in spacedquotes &&
                    (point == limit || content[point+1] == ' ')
                    currentquote = nothing
                    continue
                end
            else
                continue
            end
        end
        # quotes
        if content[point] in quotes
            currentquote = content[point]
            continue
        end
        # quotes with space
        if content[point] in spacedquotes &&
            (point == 1 || content[point-1] == ' ')
            currentquote = content[point]
            continue
        end
        # brackets
        if content[point] == open
            depth += 1
        elseif content[point] == close
            depth -= 1
        end
        if depth == 0
            return point
        end
    end
end
