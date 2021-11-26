using Dates

abstract type OrgObject <: OrgComponent end

include("../data/entities.jl")
mutable struct Entity <: OrgObject
    name::AbstractString
    post::AbstractString
end

mutable struct LaTeXFragment <: OrgObject
    contents::AbstractString
    delimiters::Union{Tuple{AbstractString, AbstractString}, Nothing}
end

mutable struct ExportSnippet <: OrgObject
    backend::AbstractString
    snippet::AbstractString
end

mutable struct FootnoteRef <: OrgObject
    label::Union{AbstractString, Nothing}
    definition::Vector{OrgObject}
end

mutable struct InlineBabelCall <: OrgObject
    name::AbstractString
    header::Union{AbstractString, Nothing}
    arguments::Union{AbstractString, Nothing}
end

mutable struct InlineSourceBlock <: OrgObject
    lang::AbstractString
    options::Union{AbstractString, Nothing}
    body::AbstractString
end

struct LineBreak <: OrgObject end

mutable struct LinkPath <: OrgObject
    protocol::Union{Symbol, AbstractString}
    path::AbstractString
end

mutable struct Link <: OrgObject
    path::LinkPath
    description::Union{AbstractString, Nothing}
end

mutable struct Macro <: OrgObject
    name::AbstractString
    arguments::Vector{AbstractString}
end

mutable struct RadioTarget <: OrgObject
    contents::AbstractString
    # contents::Vector{Union{TextMarkup, Entity, LaTeXFragment, Subscript, Superscript}}
end

mutable struct Target <: OrgObject
    target::AbstractString
end

abstract type StatisticsCookie <: OrgObject end
mutable struct StatisticsCookiePercent <: StatisticsCookie
    percentage::AbstractString
end
mutable struct StatisticsCookieFraction <: StatisticsCookie
    complete::Union{Integer, Nothing}
    total::Union{Integer, Nothing}
end

abstract type Script <: OrgObject end
mutable struct Subscript <: Script
    char::Char
    script::AbstractString
end
mutable struct Superscript <: Script
    char::Char
    script::AbstractString
end

mutable struct TableCell <: OrgObject
    contents::AbstractString
end
Base.length(cell::TableCell) = length(cell.contents)

abstract type Timestamp <: OrgObject end
mutable struct TimestampRepeaterOrDelay
    mark::AbstractString
    value::AbstractString
    unit::Char
end
mutable struct TimestampDiary <: Timestamp
    sexp::AbstractString
end
mutable struct TimestampActive <: Timestamp
    date::Date
    time::Union{Time, Nothing}
    repeater::Union{TimestampRepeaterOrDelay, Nothing}
end
mutable struct TimestampInactive <: Timestamp
    date::Date
    time::Union{Time, Nothing}
    repeater::Union{TimestampRepeaterOrDelay, Nothing}
end
mutable struct TimestampActiveRange <: Timestamp
    start::TimestampActive
    stop::TimestampActive
end
mutable struct TimestampInactiveRange <: Timestamp
    start::TimestampInactive
    stop::TimestampInactive
end

mutable struct TextPlain{S <: AbstractString} <: OrgObject
    text::S
end

mutable struct TextMarkup <: OrgObject
    type::Symbol
    marker::Char
    pre::AbstractString
    contents::Union{Vector{OrgObject}, AbstractString}
    post::AbstractString
end
