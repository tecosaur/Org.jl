using Tables

struct OrgTable{T}
    data::T
end

function Base.show(io::IO, ::MIME"text/org", x::OrgTable)
    header = [' ' * string(n) * ' ' for n in Tables.columnnames(x.data)]
    rows = Vector{String}[]
    lengths = length.(header)

    for tablerow in Tables.rows(x.data)
        row = [' ' * string(v) * ' ' for v in tablerow]
        lengths .= max.(length.(row), lengths)
        push!(rows, row)
    end

    # Write header
    for (s, l) in zip(header, lengths)
        print(io, '|', rpad(s, l))
    end
    println(io, '|')

    # Write |---+---| divider
    print(io, '|')
    let (a, rest) = Iterators.peel(lengths)
        print(io, '-'^a)
        for n in rest
            print(io, '+', '-'^n)
        end
    end
    println(io, '|')

    # Write rows
    for row in rows
        for (s, l) in zip(row, lengths)
            print(io, '|', rpad(s, l))
        end
        println(io, '|')
    end
end
