function layouttable(io::IO, printer::Function, table::Table, tchars::Dict, indent=0)
    celltext = map(r -> if r isa TableRow
                       [join(sprint.(printer, c.contents)) for c in r.cells]
                   else r end, table.rows)
    colwidths = map(r -> if !isa(r, TableHrule)
                        [textwidth(c) - ansi_escape_textwidth_offset(c) for c in r]
                    end, celltext) |>
                        rs -> filter(!isnothing, rs) |>
                        rs -> maximum(hcat(rs...); dims=2)
    for row in celltext
        print(io, ' '^indent)
        if row isa TableHrule
            print(io, tchars['>'],
                  join(repeat.(tchars['-'], colwidths .+ 2), tchars['+']),
                  tchars['<'], "\n")
        else
            print(io, tchars['|'])
            for (cell, fillwidth) in zip(row, colwidths)
                print(io, tchars['['],
                      rpad(cell, fillwidth + ansi_escape_textwidth_offset(cell)),
                      tchars[']'], tchars['|'])
            end
            row === last(celltext) || print(io, '\n')
        end
    end
end

function ansi_escape_textwidth_offset(s::AbstractString)
    escapeskip, i, slen = 0, 1, ncodeunits(s)
    while i < slen
        if s[i] == '\e' && i-1 < slen
            if s[i+1] == '[' # Control Sequence Introducer
                terminator = findfirst('m', @inbounds @view s[i:end])
                delta = if !isnothing(terminator) terminator-1 else 0 end
                escapeskip += delta
                i += delta
            elseif s[i+1] == ']' # Operating System Command
                terminator = findfirst("\e\\", @inbounds @view s[i:end])
                delta = if !isnothing(terminator) terminator.stop-1 else 0 end
                escapeskip += delta
                i += delta
            else
                @warn "Unrecognised ANSI code $(s[i+1]) in string."
            end
        end
        i = nextind(s, i)
    end
    escapeskip
end

"""
    wraplines(s::AbstractString, width::Integer, offset::Integer)
`s` is assumed to only contain significant whitespace, and no newlines
"""
function wraplines(s::AbstractString, width::Integer, offset::Integer=0)
    lines = SubString{String}[]
    i, lastwrap, slen = 1, 0, ncodeunits(s)
    mostrecentbreakoppotunity = 1
    while i < slen
        if s[i] == ' '
            mostrecentbreakoppotunity = i
        elseif s[i] == '\e'
            if s[i+1] == '[' # Control Sequence Introducer
                terminator = findfirst('m', @inbounds @view s[i:end])
                delta = if !isnothing(terminator) terminator else 0 end
                offset -= delta
                i += delta
            elseif s[i+1] == ']' # Operating System Command
                terminator = findfirst("\e\\", @inbounds @view s[i:end])
                delta = if !isnothing(terminator) terminator.stop else 0 end
                offset -= delta
                i += delta
            else
                @warn "Unrecognised ANSI code $(s[i+1]) in string."
                i = nextind(s, i)
            end
            continue
        elseif s[i] == '\n'
            push!(lines, @inbounds @view s[nextind(s, lastwrap):prevind(s, i)])
            lastwrap = i
            offset = 0
        elseif i - (lastwrap - offset) > width && mostrecentbreakoppotunity > 1
            if lastwrap == mostrecentbreakoppotunity
                nextbreak = findfirst(' ', @inbounds @view s[nextind(s, lastwrap):end])
                if isnothing(nextbreak)
                    mostrecentbreakoppotunity = slen
                else
                    mostrecentbreakoppotunity = lastwrap + nextbreak
                end
                i = mostrecentbreakoppotunity
            end
            push!(lines, @inbounds @view s[nextind(s, lastwrap):prevind(s, mostrecentbreakoppotunity)])
            lastwrap = mostrecentbreakoppotunity
            offset = 0
        end
        i = nextind(s, i)
    end
    if lastwrap < slen
        push!(lines, @inbounds @view s[nextind(s, lastwrap):end])
    end
    lines
end
