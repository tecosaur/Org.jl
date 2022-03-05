# Make modification to the content clear the cache
function Base.setproperty!(o::Org, name::Symbol, value)
    if name == :contents
        o.cache = OrgCache(o)
        setfield!(o, name, value)
    elseif name == :settings
        setfield!(o, name, value)
    else # Anything other than .contents or .settings is a cache reference
        setfield!(getfield(o, :cache), name, value)
    end
end

function Base.getproperty(o::Org, name::Symbol)
    if name == :contents || name == :settings || name == :cache
        getfield(o, name)
    else
        getproperty(getfield(o, :cache), name)
    end
end

function Base.getproperty(c::OrgCache, name::Symbol)
    if isnothing(getfield(c, name))
        setfield!(c, name, gencache(c, Val(name)))
    end
    getfield(c, name)
end

function gencache(c::OrgCache, ::Val{:elements})
    Vector{Union{Heading, Section, GreaterElement, Element}}(
        OrgElementIterator(c.doc) |> collect)
end

function gencache(c::OrgCache, ::Val{:components})
    Vector{OrgComponent}(OrgIterator(c.doc) |> collect)
end

function gencache(c::OrgCache, ::Val{:headings})
    Vector{Heading}(filter(h -> h isa Heading, c.elements))
end

function gencache(c::OrgCache, ::Val{:keywords})
    kwdict = Dict{AbstractString, Vector{AbstractString}}()
    for kw in filter(k -> k isa Keyword, c.elements)
        if haskey(kwdict, kw.key)
            push!(kwdict[kw.key], kw.value)
        else
            kwdict[kw.key] = [kw.value]
        end
    end
    kwdict
end

function gencache(c::OrgCache, ::Val{:macros})
    macros = Dict{AbstractString, Function}()
    if haskey(c.keywords, "macro")
        for (name, replacement) in split.(c.keywords["macro"], r"[ \t]+", limit=2)
            n = getproperty.(eachmatch(r"\$\d+", replacement), :match) |> unique |> length
            if startswith(replacement, "(eval ")
                if !isnothing(Sys.which("emacs"))
                    macros[name] = function(arguments)
                        if length(arguments) == n
                            elisp = replace(replacement[7:end-1], r"\$\d+" => function(i)
                                                val = arguments[parse(Int, i[2:end])]
                                                if !isnothing(match(r"^[\d\.]+$", val))
                                                    val
                                                else
                                                    sprint(show, val)
                                                end
                                            end)
                            try
                                # TODO gate this behind some sort of unsafe switch
                                read(`emacs --batch --eval "(princ $elisp)"`, String)
                            catch _
                            end
                        end
                    end
                else
                    macros[name] = _ -> nothing
                end
            else
                macros[name] = arguments -> if length(arguments) == n
                    replace(replacement, r"\$\d+" => i -> arguments[parse(Int, i[2:end])])
                end
            end
        end
    end
    macros
end

function gencache(c::OrgCache, ::Val{:footnotes})
    footnotes = Dict{Union{AbstractString, FootnoteReference}, Tuple{Int, Union{FootnoteReference, FootnoteDefinition}}}()
    i = 1
    for f in filter(f -> f isa FootnoteDefinition || f isa FootnoteReference, c.components)
        if !isnothing(f.definition)
            footnotes[something(f.label, f)] = (i, f)
            i += 1
        end
    end
    footnotes
end
