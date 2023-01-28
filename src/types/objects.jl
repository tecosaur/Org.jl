using Dates

abstract type Object <: Component end

include("../data/entities.jl")
struct Entity <: Object
    name::SubString{String}
end
Entity(name::String) = Entity(SubString(name))

struct LaTeXFragment <: Object
    contents::SubString{String}
    delimiters::Union{Tuple{SubString{String}, SubString{String}}, Nothing}
end
LaTeXFragment(contents::String, delimitors::Tuple{String,String}=("\\(", "\\)")) =
    LaTeXFragment(SubString(contents), SubString.(delimitors))

struct ExportSnippet <: Object
    backend::SubString{String}
    snippet::SubString{String}
end
ExportSnippet(backend::String, snippet::String) =
    ExportSnippet(SubString(backend), SubString(snippet))

mutable struct FootnoteReference{L <: Union{SubString{String}, Nothing},
                                 D <: Union{Vector{Object}, Nothing}} <: Object
    label::L
    definition::D
end
FootnoteReference(label::String, definition::Union{Vector{Object}, Nothing}=nothing) =
    FootnoteReference(SubString(label), definition)
FootnoteReference(::Nothing, definition::String) =
    FootnoteReference(nothing, Object[TextPlain(definition)])

mutable struct CitationReference <: Object
    prefix::Vector{Object}
    key::SubString{String}
    suffix::Vector{Object}
end
CitationReference(prefix::Vector{Object}, key::String, suffix::Vector{Object}=Object[]) =
    CitationReference(prefix, SubString(key), suffix)
CitationReference(prefix::String, key::String, suffix::String) =
    CitationReference(Object[TextPlain(prefix)], key, Object[TextPlain(suffix)])
CitationReference(prefix::String, key::String, ::Nothing=nothing) =
    CitationReference(Object[TextPlain(prefix)], key)
CitationReference(key::String, suffix::Vector{Object}=Object[]) =
    CitationReference(Object[], key, suffix)
CitationReference(::Nothing, key::String, suffix::String) =
    CitationReference(key, Object[TextPlain(suffix)])

mutable struct Citation <: Object
    style::Tuple{Union{SubString{String}, Nothing},
                 Union{SubString{String}, Nothing}}
    globalprefix::Vector{Object}
    citerefs::Vector{CitationReference}
    globalsuffix::Vector{Object}
end
Citation(style::String, gpref::Vector{Object},
         citerefs::Vector{CitationReference}, gsuf::Vector{Object}) =
    Citation((SubString(style), nothing), gpref, citerefs, gsuf)
Citation(style::Union{Tuple{String, Nothing}, Tuple{String}}, gpref::Vector{Object},
         citerefs::Vector{CitationReference}, gsuf::Vector{Object}) =
    Citation((SubString(style[1]), nothing), gpref, citerefs, gsuf)
Citation(style::Tuple{String, String}, gpref::Vector{Object},
         citerefs::Vector{CitationReference}, gsuf::Vector{Object}) =
    Citation((SubString(style[1]), SubString(style[2])), gpref, citerefs, gsuf)
Citation(style::Union{String, Tuple}, gpref::Vector{Object}, citerefs::Vector{CitationReference}) =
    Citation(style, gpref, citerefs, Object[])
Citation(gpref::Vector{Object}, citerefs::Vector{CitationReference}) =
    Citation((nothing, nothing), gpref, citerefs)
Citation(style::Union{String, Tuple}, citerefs::Vector{CitationReference}, gsuf::Vector{Object}=Object[]) =
    Citation(style, Object[], citerefs, gsuf)
Citation(citerefs::Vector{CitationReference}, gsuf::Vector{Object}=Object[]) =
    Citation((nothing, nothing), citerefs, gsuf)
Citation(style::Union{String, Tuple}, key::String) =
    Citation(style, Object[], CitationReference(key), Object[])
Citation(key::String) =
    Citation((nothing, nothing), CitationReference(key))

struct InlineBabelCall <: Object
    name::SubString{String}
    header::Union{SubString{String}, Nothing}
    arguments::Union{SubString{String}, Nothing}
end
InlineBabelCall(name::String, arguments::Union{SubString{String}, Nothing}=nothing) =
    InlineBabelCall(SubString(name), nothing, arguments)

struct InlineSourceBlock <: Object
    lang::SubString{String}
    options::Union{SubString{String}, Nothing}
    body::SubString{String}
end
InlineSourceBlock(lang::String, body::String) =
    InlineSourceBlock(SubString(lang), nothing, SubString(body))

struct LineBreak <: Object end

abstract type Link <: Object end

struct LinkPath <: Object
    protocol::Union{Symbol, SubString{String}}
    path::SubString{String}
end
LinkPath(protocol::Symbol, path::String) =
    LinkPath(protocol, SubString(path))
LinkPath(protocol::String, path::String) =
    LinkPath(SubString(protocol), SubString(path))

struct PlainLink <: Link
    path::LinkPath
end
PlainLink(protocol::Union{Symbol, String}, path::String) =
    PlainLink(LinkPath(protocol, path))

struct AngleLink <: Link
    path::LinkPath
end
AngleLink(protocol::Union{Symbol, String}, path::String) =
    AngleLink(LinkPath(protocol, path))

struct RegularLink <: Link
    path::LinkPath
    description::Union{Vector{Object}, Nothing}
end
RegularLink(protocol::Union{Symbol, String}, path::String, description::Union{Vector{Object}, Nothing}=nothing) =
    RegularLink(LinkPath(protocol, path), description)
RegularLink(protocol::Union{Symbol, String}, path::String, description::String) =
    RegularLink(LinkPath(protocol, path), Object[TextPlain(description)])

struct Macro <: Object
    name::SubString{String}
    arguments::Vector{SubString{String}}
end
Macro(name::String, arguments::Vector{String}=String[]) =
    Macro(SubString(name), SubString.(arguments))

mutable struct RadioTarget <: Object
    contents::Vector{Object}
end

mutable struct RadioLink <: Link
    radio::RadioTarget
end

mutable struct Target <: Object
    target::SubString{String}
end
Target(target::String) = Target(SubString(target))

abstract type StatisticsCookie <: Object end
struct StatisticsCookiePercent <: StatisticsCookie
    percentage::SubString{String}
end
struct StatisticsCookieFraction <: StatisticsCookie
    complete::Union{Integer, Nothing}
    total::Union{Integer, Nothing}
end
StatisticsCookie() = StatisticsCookieFraction(nothing, nothing)
StatisticsCookie(complete::Integer, total::Integer) =
    StatisticsCookieFraction(complete, total)
StatisticsCookie(percentage::String) =
    StatisticsCookiePercent(SubString(percentage))
StatisticsCookie(percentage::Float64) =
    StatisticsCookiePercent(SubString(string(round(Int, 100*percentage), '%')))

abstract type Script <: Object end
struct Subscript <: Script
    char::Char
    script::SubString{String}
end
Subscript(char::Char, script::String) = Subscript(char, SubString(script))
struct Superscript <: Script
    char::Char
    script::SubString{String}
end
Superscript(char::Char, script::String) = Superscript(char, SubString(script))

mutable struct TableCell <: Object
    contents::Vector{Object}
end
TableCell(text::String) = TableCell(Object[TextPlain(text)])

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
    function TimestampActive(date::Date, time::Union{Time, Nothing}=nothing,
                             repeater::Union{TimestampRepeaterOrDelay, Nothing}=nothing,
                             warning::Union{TimestampRepeaterOrDelay, Nothing}=nothing)
        new(date, time, repeater, warning)
    end
end
TimestampActive(datetime::DateTime) =
    TimestampActive(Date(datetime), Time(datetime))
mutable struct TimestampInactive <: TimestampInstant
    date::Date
    time::Union{Time, Nothing}
    repeater::Union{TimestampRepeaterOrDelay, Nothing}
    warning::Union{TimestampRepeaterOrDelay, Nothing}
    function TimestampInactive(date::Date, time::Union{Time, Nothing}=nothing,
                               repeater::Union{TimestampRepeaterOrDelay, Nothing}=nothing,
                               warning::Union{TimestampRepeaterOrDelay, Nothing}=nothing)
        new(date, time, repeater, warning)
    end
end
TimestampInactive(datetime::DateTime) =
    TimestampInactive(Date(datetime), Time(datetime))
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
function TextMarkup(formatting::Symbol, contents::String)
    if formatting in ('=', '~')
        TextMarkup(formatting, SubString(contents))
    else
        TextMarkup(formatting, TextPlain(contents))
    end
end

struct TextPlain{S <: Union{SubString{String}, String}} <: Object
    text::S
end
