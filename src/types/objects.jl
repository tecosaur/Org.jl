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

mutable struct FootnoteRef{L <: Union{<:AbstractString, Nothing},
                           D <: Union{Vector{OrgObject}, Nothing}} <: OrgObject
    label::L
    definition::D
end

mutable struct KeyCite <: OrgObject
    prefix::Union{AbstractString, Nothing}
    key::Vector{OrgObject}
    suffix::Union{AbstractString, Nothing}
end

mutable struct Citation <: OrgObject
    style::Tuple{Union{AbstractString, Nothing},
                 Union{AbstractString, Nothing}}
    globalprefix::Union{AbstractString, Nothing}
    keycites::Vector{KeyCite}
    globalsuffix::Union{AbstractString, Nothing}
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
    contents::Vector{OrgObject}
end

abstract type Timestamp <: OrgObject end
mutable struct TimestampRepeaterOrDelay
    type::Symbol
    value::Real
    unit::Char
end
mutable struct TimestampDiary <: Timestamp
    sexp::AbstractString
end
abstract type TimestampInstant <: Timestamp end
mutable struct TimestampActive <: TimestampInstant
    date::Date
    time::Union{Time, Nothing}
    repeater::Union{TimestampRepeaterOrDelay, Nothing}
    warning::Union{TimestampRepeaterOrDelay, Nothing}
end
mutable struct TimestampInactive <: TimestampInstant
    date::Date
    time::Union{Time, Nothing}
    repeater::Union{TimestampRepeaterOrDelay, Nothing}
    warning::Union{TimestampRepeaterOrDelay, Nothing}
end
abstract type TimestampRange <: Timestamp end
mutable struct TimestampActiveRange <: TimestampRange
    start::TimestampActive
    stop::TimestampActive
end
mutable struct TimestampInactiveRange <: TimestampRange
    start::TimestampInactive
    stop::TimestampInactive
end

mutable struct TextPlain{S <: AbstractString} <: OrgObject
    text::S
end

mutable struct TextMarkup{C <: Union{Vector{OrgObject}, <:AbstractString}} <: OrgObject
    type::Symbol
    marker::Char
    pre::AbstractString
    contents::C
    post::AbstractString
end

mutable struct RadioTarget <: OrgObject
    contents::Vector{Union{TextPlain, TextMarkup, Entity, LaTeXFragment, Subscript, Superscript}}
end
