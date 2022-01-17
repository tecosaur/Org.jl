struct AffiliatedKeywordsWrapper{E <: Element} <: Element
    element::E
    keywords::Vector{AffiliatedKeyword}
end
