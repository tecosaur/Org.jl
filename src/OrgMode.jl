module OrgMode

export Org, @org_str

include("types/org.jl")

include("parse/interpret.jl")
include("analysis/parsetree.jl")

macro org_str(content::String)
    parse(Org, content)
end

include("render/formatting.jl")
include("render/org.jl")
include("render/term.jl")

Base.show(io::IO, ::MIME"text/org", org::Org) = (org(io, org), nothing)
function Base.show(io::IO, ::MIME"text/plain", org::Org)
    if io === stdout && displaysize(io)[2] != 80
        termwidth = displaysize(io)[2]
        narrowedio = IOContext(io, :displaysize => (displaysize(io)[1], round(Int, 0.9*termwidth)))
        (term(narrowedio, org), nothing)
    else
        (term(io, org), nothing)
    end
end

include("types/documentation.jl")

include("analysis/parsetree.jl")
include("analysis/diff.jl")

end
