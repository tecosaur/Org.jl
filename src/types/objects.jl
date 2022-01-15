using Dates

abstract type OrgObject <: OrgComponent end

include("../data/entities.jl")
struct Entity <: OrgObject
    name::AbstractString
end

struct LaTeXFragment <: OrgObject
    contents::AbstractString
    delimiters::Union{Tuple{AbstractString, AbstractString}, Nothing}
end

struct ExportSnippet <: OrgObject
    backend::AbstractString
    snippet::AbstractString
end

mutable struct FootnoteReference{L <: Union{<:AbstractString, Nothing},
                                 D <: Union{Vector{OrgObject}, Nothing}} <: OrgObject
    label::L
    definition::D
end

mutable struct CitationReference <: OrgObject
    prefix::Vector{OrgObject}
    key::AbstractString
    suffix::Vector{OrgObject}
end

mutable struct Citation <: OrgObject
    style::Tuple{Union{AbstractString, Nothing},
                 Union{AbstractString, Nothing}}
    globalprefix::Vector{OrgObject}
    citerefs::Vector{CitationReference}
    globalsuffix::Vector{OrgObject}
end

struct InlineBabelCall <: OrgObject
    name::AbstractString
    header::Union{AbstractString, Nothing}
    arguments::Union{AbstractString, Nothing}
end

struct InlineSourceBlock <: OrgObject
    lang::AbstractString
    options::Union{AbstractString, Nothing}
    body::AbstractString
end

struct LineBreak <: OrgObject end

abstract type Link <: OrgObject end

struct LinkPath <: OrgObject
    protocol::Union{Symbol, AbstractString}
    path::AbstractString
end

struct PlainLink <: Link
    path::LinkPath
end

struct AngleLink <: Link
    path::LinkPath
end

struct RegularLink <: Link
    path::LinkPath
    description::Union{Vector{OrgObject}, Nothing}
end

struct Macro <: OrgObject
    name::AbstractString
    arguments::Vector{AbstractString}
end

mutable struct RadioTarget <: OrgObject
    contents::Vector{OrgObject}
end

mutable struct RadioLink <: Link
    radio::RadioTarget
end

mutable struct Target <: OrgObject
    target::AbstractString
end

abstract type StatisticsCookie <: OrgObject end
struct StatisticsCookiePercent <: StatisticsCookie
    percentage::AbstractString
end
struct StatisticsCookieFraction <: StatisticsCookie
    complete::Union{Integer, Nothing}
    total::Union{Integer, Nothing}
end

abstract type Script <: OrgObject end
struct Subscript <: Script
    char::Char
    script::AbstractString
end
struct Superscript <: Script
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

mutable struct TextMarkup{C <: Union{Vector{OrgObject}, <:AbstractString}} <: OrgObject
    formatting::Symbol
    contents::C
end

struct TextPlain{S <: AbstractString} <: OrgObject
    text::S
end
