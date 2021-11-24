abstract type OrgComponent end

mutable struct Org <: Any
    content::Vector{OrgComponent}
end
Org() = Org([])

struct OrgParseError <: Exception
    element::Union{DataType, Nothing}
    msg::AbstractString
end

function Base.showerror(io::IO, ex::OrgParseError)
    print(io, "Org parse error")
    if !isnothing(ex.element)
        print(io, " in element $(ex.element): ")
    else
        print(io, ": ")
    end
    print(io, ex.msg)
    Base.Experimental.show_error_hints(io, ex)
end

macro parseassert(elem, expr::Expr, msg)
    function matchp(e::Expr)
        if e.head == :call && e.args[1] == :match
            e = :(!(isnothing($e)))
        else
            e.args = map(matchp, e.args)
        end
        e
    end
    matchp(e::Any) = e
    expr = matchp(expr)
    quote
        if !($(esc(expr)))
            throw(OrgParseError($(esc(elem)), $(esc(msg))))
        end
    end
end

include("convertor.jl")
include("sections.jl")
include("operations.jl")
