struct AffiliatedKeywordsWrapper{E <: Element} <: Element
    element::E
    keywords::Vector{AffiliatedKeyword}
end

AffiliatedKeywordsWrapper(element::Element, keywords::Vector{<:Pair{String, <:Any}}) =
    AffiliatedKeywordsWrapper(element, AffiliatedKeyword.(keywords))
