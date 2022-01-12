mutable struct OrgCache
    doc
    headings::Union{Nothing, Vector{Heading}}
    elements::Union{Nothing, Vector{Union{Heading, Section, OrgGreaterElement, OrgElement}}}
    components::Union{Nothing, Vector{OrgComponent}}
    keywords::Union{Nothing, Dict{AbstractString, Vector{AbstractString}}}
    macros::Union{Nothing, Dict{AbstractString, Function}}
    footnotes::Union{Nothing, Dict{Union{AbstractString, FootnoteReference},
                                   Tuple{Int, Union{FootnoteDef, FootnoteReference}}}}
end

OrgCache(doc) = OrgCache(doc, nothing, nothing, nothing,
                         nothing, nothing, nothing)
OrgCache() = OrgCache(nothing)
