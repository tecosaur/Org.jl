# ---------------------
# Sections
# ---------------------

# ---------------------
# Greater elements
# ---------------------

const table_charset_org =
    Dict('|' => '|',
         '>' => '|',
         '<' => '|',
         '[' => ' ',
         ']' => ' ',
         '-' => '-',
         '+' => '+')
const table_charset_boxdraw =
    Dict('|' => '│',
         '>' => '├',
         '<' => '┤',
         '[' => ' ',
         ']' => ' ',
         '-' => '─',
         '+' => '┼')
const table_charset_boxdraw_slim =
    Dict('|' => ' ',
         '>' => ' ',
         '<' => ' ',
         '[' => "",
         ']' => "",
         '-' => '─',
         '+' => '─')

function org(io::IO, table::Table, tchars::Dict=table_charset_org)
    colwidths = map(r -> if r isa TableRow
                        length.(r.cells)
                    end, table.rows) |>
                        rs -> filter(!isnothing, rs) |>
                        rs -> maximum(hcat(rs...); dims=2)
    for row in table.rows
        if row isa TableHrule
            print(io, tchars['>'], join(repeat.(tchars['-'], colwidths .+ 2), tchars['+']), tchars['<'], "\n")
        else
            print(io, tchars['|'])
            for (cell, fillwidth) in zip(row.cells, colwidths)
                print(tchars['['], rpad(cell.contents, fillwidth), tchars[']'], tchars['|'])
            end
            print(io, "\n")
        end
    end
end

# ---------------------
# Elements
# ---------------------

# ---------------------
# Objects
# ---------------------

# OrgEntity

function org(io::IO, latex::LaTeXFragment)
    if isnothing(latex.delimiters)
        print(io, latex.delimiters[1], latex.contents, latex.delimiters[2])
    else
        print(io. latex.contents)
    end
end
