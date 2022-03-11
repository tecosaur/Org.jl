module Org

export OrgDoc, @org_str,              # types/org.jl, here
    org, term, tableofcontents, html, # render/*
    parsetree                         # analysis/parsetree.jl

include("types/org.jl")
include("cache/cache.jl")

include("parse/interpret.jl")
include("parse/markdown.jl")

const org_str_typeflags =
    Dict("d" => OrgDoc,
         "e" => Element,
         "o" => Object,
         "h" => Heading,
         "s" => Section,
         "p" => Paragraph,
         "ts" => Timestamp,
         "m" => TextMarkup,
         "t" => TextPlain)

macro org_str(content::String, type::String="d")
    if !haskey(org_str_typeflags, type)
        throw(ArgumentError(
            string("Unknown Org type flag: $type",
                   "\n\nRecognised types flags:\n",
                   join(map(((short, type)::Pair -> " • $short, $type"),
                            collect(org_str_typeflags)), '\n'), '\n')))
    end
    parse(org_str_typeflags[type], content)
end

include("types/documentation.jl")
include("parse/documentation.jl")

include("render/utils.jl")
include("render/formatting.jl")
include("render/org.jl")
include("render/term.jl")
include("render/html.jl")

include("analysis/parsetree.jl")
include("analysis/diff.jl")

include("precompile.jl")

end
