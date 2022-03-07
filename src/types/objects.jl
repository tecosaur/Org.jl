using Dates

abstract type Object <: OrgComponent end

include("../data/entities.jl")
struct Entity <: Object
    name::AbstractString
end

struct LaTeXFragment <: Object
    contents::AbstractString
    delimiters::Union{Tuple{AbstractString, AbstractString}, Nothing}
end

struct ExportSnippet <: Object
    backend::AbstractString
    snippet::AbstractString
end

mutable struct FootnoteReference{L <: Union{<:AbstractString, Nothing},
                                 D <: Union{Vector{Object}, Nothing}} <: Object
    label::L
    definition::D
end

mutable struct CitationReference <: Object
    prefix::Vector{Object}
    key::AbstractString
    suffix::Vector{Object}
end

mutable struct Citation <: Object
    style::Tuple{Union{AbstractString, Nothing},
                 Union{AbstractString, Nothing}}
    globalprefix::Vector{Object}
    citerefs::Vector{CitationReference}
    globalsuffix::Vector{Object}
end

struct InlineBabelCall <: Object
    name::AbstractString
    header::Union{AbstractString, Nothing}
    arguments::Union{AbstractString, Nothing}
end

struct InlineSourceBlock <: Object
    lang::AbstractString
    options::Union{AbstractString, Nothing}
    body::AbstractString
end

struct LineBreak <: Object end

abstract type Link <: Object end

struct LinkPath <: Object
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
    description::Union{Vector{Object}, Nothing}
end

struct Macro <: Object
    name::AbstractString
    arguments::Vector{AbstractString}
end

mutable struct RadioTarget <: Object
    contents::Vector{Object}
end

mutable struct RadioLink <: Link
    radio::RadioTarget
end

mutable struct Target <: Object
    target::AbstractString
end

abstract type StatisticsCookie <: Object end
struct StatisticsCookiePercent <: StatisticsCookie
    percentage::AbstractString
end
struct StatisticsCookieFraction <: StatisticsCookie
    complete::Union{Integer, Nothing}
    total::Union{Integer, Nothing}
end

abstract type Script <: Object end
struct Subscript <: Script
    char::Char
    script::AbstractString
end
struct Superscript <: Script
    char::Char
    script::AbstractString
end

mutable struct TableCell <: Object
    contents::Vector{Object}
end

abstract type Timestamp <: Object end
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

mutable struct TextMarkup{C <: Union{Vector{Object}, <:AbstractString}} <: Object
    formatting::Symbol
    contents::C
end

struct TextPlain{S <: AbstractString} <: Object
    text::S
end
