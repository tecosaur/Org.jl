function layouttable(io::IO, table::Table, tchars::Dict, indent=0)
    colwidths = map(r -> if r isa TableRow
                        length.(r.cells)
                    end, table.rows) |>
                        rs -> filter(!isnothing, rs) |>
                        rs -> maximum(hcat(rs...); dims=2)
    for row in table.rows
        print(io, ' '^indent)
        if row isa TableHrule
            print(io, tchars['>'], join(repeat.(tchars['-'], colwidths .+ 2), tchars['+']), tchars['<'], "\n")
        else
            print(io, tchars['|'])
            for (cell, fillwidth) in zip(row.cells, colwidths)
                print(io, tchars['['], rpad(cell.contents, fillwidth), tchars[']'], tchars['|'])
            end
            row === last(table.rows) || print(io, '\n')
        end
    end
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
                @warn "Unrecognised ANSI code in string."
                i = nextind(s, i)
            end
            continue
        elseif s[i] == '\n'
            push!(lines, @inbounds @view s[nextind(s, lastwrap):prevind(s, i)])
            lastwrap = i
            offset = 0
        elseif i - (lastwrap - offset) > width
            if lastwrap == mostrecentbreakoppotunity
                nextbreak = findfirst(' ', @inbounds @view s[nextind(s, lastwrap):end])
                if isnothing(nextbreak)
                    mostrecentbreakoppotunity = slen
                else
                    mostrecentbreakoppotunity = nextbreak
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
