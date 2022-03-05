function macroexpand(o::Org, m::Macro)
    if m.name in ("title", "author", "email") &&
        haskey(o.keywords, m.name)
        join(o.keywords[m.name], ' ')
    elseif m.name == "keyword" && length(m.arguments) == 1 &&
        haskey(o.keywords, m.arguments[1])
        join(o.keywords[m.arguments[1]], ' ')
    elseif m.name == "date" && haskey(o.keywords, "date")
        if length(m.arguments) == 0
            o.keywords["date"][1]
        else
            date_timestamp = consume(Timestamp, o.keywords["date"][1])
            if !isnothing(date_timestamp)
                seconds = if !isnothing(date_timestamp[2].time)
                    DateTime(date_timestamp[2].date, date_timestamp[2].time)
                else
                    DateTime(date_timestamp[2].date)
                end |> datetime2unix
                Base.Libc.strftime(m.arguments[1], seconds)
            end
        end
    elseif m.name == "time" && length(m.arguments) > 0
        Base.Libc.strftime(m.arguments[1], time())
    # TODO support n macro ... somehow
    elseif m.name in keys(o.macros)
        o.macros[m.name](m.arguments)
    elseif m.name == "results" && length(m.arguments) == 1
        "=$(m.arguments[1])="
    end
end
