mutable struct OrgCache
    doc
    headings::Union{Nothing, Vector{Heading}}
    elements::Union{Nothing, Vector{Element}}
    components::Union{Nothing, Vector{OrgComponent}}
    keywords::Union{Nothing, Dict{SubString{String}, Vector{SubString{String}}}}
    macros::Union{Nothing, Dict{SubString{String}, Function}}
    footnotes::Union{Nothing, Dict{Union{SubString{String}, FootnoteReference},
                                   Tuple{Int, Union{FootnoteDefinition, FootnoteReference}}}}
end

OrgCache(doc) = OrgCache(doc, nothing, nothing, nothing,
                         nothing, nothing, nothing)
OrgCache() = OrgCache(nothing)
