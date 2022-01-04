mutable struct OrgCache
    doc
    footnotes::Union{Nothing, Dict{Union{AbstractString, FootnoteRef},
                                   Tuple{Int, Union{FootnoteDef, FootnoteRef}}}}
end

OrgCache(doc) = OrgCache(doc, nothing)
OrgCache() = OrgCache(nothing)
