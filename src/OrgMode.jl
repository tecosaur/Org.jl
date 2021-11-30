module OrgMode

export Org, @org_str,          # types/org.jl, here
    flatten, filtermap,        # parse/operations.jl
    org, term, contents, html, # render/*
    parsetree                  # analysis/parsetree.jl

include("types/org.jl")

include("parse/interpret.jl")

macro org_str(content::String)
    parse(Org, content)
end

include("types/documentation.jl")
include("parse/documentation.jl")

include("render/formatting.jl")
include("render/org.jl")
include("render/term.jl")
include("render/html.jl")

include("analysis/parsetree.jl")
include("analysis/diff.jl")

end
