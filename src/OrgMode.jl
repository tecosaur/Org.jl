module OrgMode

export Org, @org_str

include("types/org.jl")

include("parse/interpret.jl")

macro org_str(content::String)
    parse(Org, content)
end

import Base.show
include("render/org.jl")
include("render/term.jl")

include("types/documentation.jl")

end
