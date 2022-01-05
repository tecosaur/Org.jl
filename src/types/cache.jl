mutable struct OrgCache
    doc
    headings::Union{Nothing, Vector{Heading}}
    elements::Union{Nothing, Vector{Union{Heading, Section, OrgGreaterElement, OrgElement}}}
    components::Union{Nothing, Vector{OrgComponent}}
    keywords::Union{Nothing, Dict{AbstractString, Vector{AbstractString}}}
    footnotes::Union{Nothing, Dict{Union{AbstractString, FootnoteRef},
                                   Tuple{Int, Union{FootnoteDef, FootnoteRef}}}}
end

OrgCache(doc) = OrgCache(doc, nothing, nothing, nothing, nothing, nothing)
OrgCache() = OrgCache(nothing)
