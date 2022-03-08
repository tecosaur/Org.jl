using Dates

abstract type Object <: OrgComponent end

include("../data/entities.jl")
struct Entity <: Object
    name::SubString{String}
end

struct LaTeXFragment <: Object
    contents::SubString{String}
    delimiters::Union{Tuple{SubString{String}, SubString{String}}, Nothing}
end

struct ExportSnippet <: Object
    backend::SubString{String}
    snippet::SubString{String}
end

mutable struct FootnoteReference{L <: Union{SubString{String}, Nothing},
                                 D <: Union{Vector{Object}, Nothing}} <: Object
    label::L
    definition::D
end

mutable struct CitationReference <: Object
    prefix::Vector{Object}
    key::SubString{String}
    suffix::Vector{Object}
end

mutable struct Citation <: Object
    style::Tuple{Union{SubString{String}, Nothing},
                 Union{SubString{String}, Nothing}}
    globalprefix::Vector{Object}
    citerefs::Vector{CitationReference}
    globalsuffix::Vector{Object}
end

struct InlineBabelCall <: Object
    name::SubString{String}
    header::Union{SubString{String}, Nothing}
    arguments::Union{SubString{String}, Nothing}
end

struct InlineSourceBlock <: Object
    lang::SubString{String}
    options::Union{SubString{String}, Nothing}
    body::SubString{String}
end

struct LineBreak <: Object end

abstract type Link <: Object end

struct LinkPath <: Object
    protocol::Union{Symbol, SubString{String}}
    path::SubString{String}
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
    name::SubString{String}
    arguments::Vector{SubString{String}}
end

mutable struct RadioTarget <: Object
    contents::Vector{Object}
end

mutable struct RadioLink <: Link
    radio::RadioTarget
end

mutable struct Target <: Object
    target::SubString{String}
end

abstract type StatisticsCookie <: Object end
struct StatisticsCookiePercent <: StatisticsCookie
    percentage::SubString{String}
end
struct StatisticsCookieFraction <: StatisticsCookie
    complete::Union{Integer, Nothing}
    total::Union{Integer, Nothing}
end

abstract type Script <: Object end
struct Subscript <: Script
    char::Char
    script::SubString{String}
end
struct Superscript <: Script
    char::Char
    script::SubString{String}
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
    sexp::SubString{String}
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

mutable struct TextMarkup{C <: Union{Vector{Object}, SubString{String}}} <: Object
    formatting::Symbol
    contents::C
end

struct TextPlain{S <: Union{SubString{String}, String}} <: Object
    text::S
end
