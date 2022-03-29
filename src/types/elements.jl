abstract type Element <: Component end

include("lesserelements.jl")
include("greaterelements.jl")
include("affiliatedkeywords.jl")
include("sectioning.jl")

# Taken out of greaterelements.jl for load order reasons
mutable struct InlineTask <: GreaterElement
    heading::Heading
end
