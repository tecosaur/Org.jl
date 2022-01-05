function macroexpand(o::Org, m::Macro)
    if m.name in ("title", "author", "email") &&
        haskey(o.keywords, m.name)
        join(o.keywords[m.name], ' ')
    elseif m.name == "keyword" &&
        haskey(o.keywords, m.name)
        join(o.keywords[m.name], ' ')
        # TODO support DATE, Base.Libc.strftime will probaby be useful
        # TODO support n macro ... somehow
    elseif m.name in keys(o.macros)
        o.macros[m.name](m.arguments)
    elseif m.name == "results" && length(m.arguments) == 1
        "=$(m.arguments[1])="
    end
end
