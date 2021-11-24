include("greaterelements.jl") # Org Syntax §3

mutable struct Heading <: OrgComponent # Org Syntax §1
    # STARS KEYWORD PRIORITY TITLE TAGS
    level::Integer
    keyword::Union{AbstractString, Nothing}
    priority::Union{AbstractString, Nothing}
    title::AbstractString
    tags::Vector{AbstractString}
end
const HeadingRegex = r"^(\*+)(?: +([A-Z]{2,}))?(?: +\[#([A-Z0-9])\])? +([^\n]*?)(?: +(:[A-Za-z0-9_\@#%][A-Za-z0-9_\@#%:]*:))?$"
function Heading(content::AbstractString)
    headingmatch = match(HeadingRegex, content)
    @parseassert(Heading, !isnothing(headingmatch),
                 "\"$content\" did not match any recognised form")
    stars, keyword, priority, title, tags = headingmatch.captures
    level = length(stars)
    tagsvec = if isnothing(tags); [] else split(tags[2:end-1], ':') end
    Heading(level, keyword, priority, title, tagsvec)
end

Heading(level, title, tags::Vector{AbstractString}) = Heading(level, nothing, nothing, title, tags)
Heading(level, title) = Heading(level, title, String[])

mutable struct Section <: OrgComponent # Org Syntax §1
    heading::Heading
    content::Vector{OrgComponent}
end
