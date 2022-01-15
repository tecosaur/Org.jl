function Base.show(io::IO, ::MIME"text/plain", org::Org)
    if get(io, :compact, false)
        print(io, "Org(", length(org), " children)")
    else
        termwidth = displaysize(io)[2]
        narrowedio = IOContext(io, :displaysize => (displaysize(io)[1], min(80, termwidth)))
        term(narrowedio, org)
    end
end

function term(io::IO, o::Org, indent::Integer=2)
    term(io, o, o.contents, indent)
    termfootnotes(io, o, indent)
end

function term(io::IO, o::Org, component::OrgComponent, indent::Integer)
    print(io, ' '^indent)
    term(io, o, component)
end

term(io::IO, ::Org, component::OrgComponent) =
    term(io, component)

function term(io::IO, o::Org, components::Vector{<:OrgComponent}, indent::Integer=2)
    for component in components
        (component isa Heading && component !== first(components)) && print(io, '\n')
        term(io, o, component, indent)
        component === last(components) || print(io, '\n')
    end
end

term(o::Org) = term(stdout, o, 2)
term(c::OrgComponent) = term(stdout, Org(), c, 2)
term(p::Paragraph) = (term(stdout, p, 2); print('\n'))
term(o::OrgObject) = (term(stdout, Org(), o, 2); print('\n'))

# ---------------------
# Sections
# ---------------------

const HeadingKeywordColors = Dict("TODO" => :green,
                                  "PROJ" => :light_black,
                                  "LOOP" => :green,
                                  "STRT" => :magenta,
                                  "WAIT" => :yellow,
                                  "HOLD" => :yellow,
                                  "IDEA" => :green,
                                  "DONE" => :light_black,
                                  "KILL" => :red,
                                  "[ ]" => :green,
                                  "[?]" => :yellow,
                                  "[-]" => :magenta,
                                  "[X]" => :light_black)

function termheadingonly(io::IO, heading::Heading)
    printstyled(io, '*'^heading.level, ' ', bold=true, color=:blue)
    if !isnothing(heading.keyword)
        kcolor = if heading.keyword in keys(HeadingKeywordColors)
            HeadingKeywordColors[heading.keyword]
        else
            :green
        end
        printstyled(io, heading.keyword, ' ', color=kcolor)
    end
    if !isnothing(heading.priority)
        printstyled(io, "[#", heading.priority, "] ", color=:light_red)
    end
    print(io, termstyle("34"))
    for obj in heading.title
        term(io, obj, ["34"])
    end
    print(io, termstyle(String[]))
    if length(heading.tags) > 0
        printstyled(io, " :", join(heading.tags, ":"), ":", color=:light_black)
    end
end

function term(io::IO, o::Org, heading::Heading, indent::Integer=0)
    print(io, ' '^indent)
    termheadingonly(io, heading)
    if !isnothing(heading.planning)
        print(io, '\n')
        term(io, o, heading.planning, indent)
    end
    # Don't show properties
    if !isnothing(heading.section)
        print(io, "\n\n")
        term(io, o, heading.section, indent)
    end
end

function term(io::IO, o::Org, section::Section, indent::Integer=0)
    for component in section.contents
        component isa FootnoteDefinition && continue
        term(io, o, component, indent)
        component === last(section.contents) || print(io, "\n\n")
    end
end

# Extras

function tableofcontents(io::IO, org::Org, depthrange::UnitRange=1:9, indent::Integer=2)
    for h in org.headings
        if h.level in depthrange
            print(io, ' '^indent)
            termheadingonly(io, h)
            print(io, '\n')
        end
    end
end

tableofcontents(org::Org, depthrange::UnitRange=1:9, indent::Integer=2) =
    tableofcontents(stdout, org, depthrange, indent)

tableofcontents(io::IO, org::Org, depth::Integer, indent::Integer=2) =
    tableofcontents(io, org, depth:depth, indent)

tableofcontents(org::Org, depth) = tableofcontents(stdout, org, depth)

function termfootnotes(io::IO, o::Org, indent::Integer=0)
    footnotes = collect(o.footnotes)
    if length(footnotes) > 0
        sort!(footnotes, by=f->f.second[1])
        print(io, "\n\n")
        for (i, fn) in map(f->f.second, footnotes)
            if fn isa FootnoteReference
                term(io, o, FootnoteDefinition(string(i), [Paragraph(fn.definition)]), indent)
            else
                term(io, o, FootnoteDefinition(string(i), fn.definition), indent)
            end
            i == length(footnotes) || println(io, '\n')
        end
    end
end

# ---------------------
# Greater Elements
# ---------------------

# Greater Block

function term(io::IO, o::Org, drawer::Drawer, indent::Integer=0)
    for component in drawer.contents
        component isa FootnoteDefinition && continue
        term(io, o, component, indent)
        component === last(drawer.contents) || print(io, '\n')
    end
end

# Dynamic Block

function term(io::IO, o::Org, fn::FootnoteDefinition, indent::Integer=0)
    printstyled(io, ' '^indent, "[", fn.label, "] ", color=:yellow)
    contentbuf = IOContext(IOBuffer(), :color => get(io, :color, false),
                           :displaysize => (displaysize(io)[1],
                                            displaysize(io)[2] - indent - 2))
    parlines = if fn.definition[1] isa Paragraph
        for obj in fn.definition[1]; term(contentbuf, o, obj) end
        contents = String(take!(contentbuf.io))
        wraplines(contents, displaysize(io)[2] - indent, 6 + ncodeunits(fn.label))
    else
        [""]
    end
    components = @view fn.definition[if fn.definition[1] isa Paragraph 2 else 1 end:end]
    for component in components
        term(contentbuf, o, component, indent)
        component === last(components) || print(contentbuf, '\n')
    end
    otherlines = split(String(take!(contentbuf.io)), '\n')
    lines = vcat(parlines, if otherlines == [""]; [] else otherlines end)
    for line in lines
        print(io, line)
        line === last(lines) || print(io, '\n', ' '^indent)
    end
end

# InlineTask

function term(io::IO, o::Org, item::Item, unordered::Bool=true, indent::Integer=0, depth::Integer=0)
    print(io, ' '^indent)
    offset = indent
    if unordered
        printstyled(io, if depth % 2 == 0 '•' else '➤' end, color=:blue)
    else
        printstyled(io, item.bullet, color=:blue)
    end
    offset += length(item.bullet)
    if !isnothing(item.checkbox)
        printstyled(io, " [", item.checkbox, ']',
                    color=Dict(' ' => :green, '-' => :magenta, 'X' => :light_black)[item.checkbox])
        offset += 4
    end
    if !isnothing(item.tag)
        printstyled(io, ' ', item.tag, " ::", color=:blue)
        offset += length(item.tag) + 3
    end
    if length(item.contents) > 0
        print(io, ' ')
        offset += 1
        contentbuf = IOContext(IOBuffer(), :color => get(io, :color, false),
                               :displaysize => (displaysize(io)[1],
                                                displaysize(io)[2] - indent - 2))
        parlines = if item.contents[1] isa Paragraph
            for obj in item.contents[1]; term(contentbuf, o, obj) end
            contents = String(take!(contentbuf.io))
            wraplines(contents, displaysize(io)[2] - indent - 2, offset)
        else
            ["\n"]
        end
        components = @view item.contents[if item.contents[1] isa Paragraph 2 else 1 end:end]
        for component in components
            if component isa List
                term(contentbuf, o, component, indent, depth+1)
            else
                term(contentbuf, o, component, indent)
            end
            component === last(components) || print(contentbuf, '\n')
        end
        otherlines = split(String(take!(contentbuf.io)), '\n')
        lines = vcat(parlines, if otherlines == [""]; [] else otherlines end)
        for line in lines
            print(io, line)
            line === last(lines) || print(io, '\n', ' '^(indent+2))
        end
    end
end

function term(io::IO, o::Org, list::List, indent::Integer=0, depth=0)
    for item in list.items
        term(io, o, item, list isa UnorderedList, indent, depth)
        item === last(list.items) || print(io, '\n')
    end
end

term(::IO, ::PropertyDrawer, _::Integer=0) = nothing

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

function term(io::IO, o::Org, table::Table, indent::Integer=0)
    printer = (io, c) -> term(io, o, c)
    layouttable(io, printer, table, table_charset_boxdraw, indent)
end

# ---------------------
# Elements
# ---------------------

term(::IO, ::BabelCall) = nothing

function printblockcontent(io, prefix::AbstractString, prefixcolor::Symbol, lines::Vector{<:AbstractString}, contentcolor::Symbol=:default)
    printstyled(io, prefix, color=prefixcolor)
    if length(lines) > 0
        printstyled(io, lines[1], color=contentcolor)
        if length(lines) > 1
            for line in lines[2:end]
                printstyled(io, '\n', prefix, color=prefixcolor)
                printstyled(io, line, color=contentcolor)
            end
        end
    end
end

term(::IO, ::CommentBlock) = nothing

function term(io::IO, block::Block)
    name, data = if block isa VerseBlock
        ("verse", nothing)
    elseif block isa ExportBlock
    ("export", block.backend)
    elseif block isa CustomBlock
        (block.name, block.data)
    end
    printstyled(io, "#+begin_", name, color=:light_grey)
    if !isnothing(data)
        print(io, ' ', data)
    end
    print(io, '\n')
    if block isa VerseBlock
        print(io, "Oh noes! A verse block...\n")
    else
        for line in block.contents
            if startswith(line, '*')
                print(io, ',')
            end
            print(io, line, '\n')
        end
    end
    printstyled(io, "#+end_", name, color=:light_grey)
end

term(io::IO, ::Org, block::ExampleBlock, indent::Integer=0) =
    printblockcontent(io, ' '^indent * "║ ", :light_black, block.contents, :cyan)

function term(io::IO, ::Org, srcblock::SourceBlock, indent::Integer=0)
    printstyled(io, ' '^indent, "╭", color=:light_black)
    if !isnothing(srcblock.lang)
        printstyled(io, '╴', srcblock.lang, '\n', color=:light_black)
    else
        print(io, '\n')
    end
    printblockcontent(io, ' '^indent * "│ ", :light_black, srcblock.contents, :cyan)
    printstyled(io, '\n', ' '^indent,"╰", color=:light_black)
end

# Clock

# DiarySexp

function term(io::IO, ::Org, planning::Planning)
    values = [(type, getproperty(planning, type))
              for type in (:deadline, :scheduled, :closed)] |>
                  vals -> filter(v -> !isnothing(v[2]), vals)
    for val in values
        printstyled(io, uppercase(string(val[1])), ' ', bold=true, color=:light_black)
        term(io, val[2])
        val === last(values) || print(io, ' ')
    end
end

term(::IO, ::Comment, _::Integer=0) = nothing

term(io::IO, fw::FixedWidth, indent::Integer=0) =
    printblockcontent(io, ' '^indent * "║ ", :light_black, fw.contents, :cyan)

term(io::IO, ::HorizontalRule) =
    printstyled(io, ' ', '─'^(displaysize(io)[2]-2), '\n', color=:light_black)

const DocumentInfoKeywords = ["title", "subtitle", "author"]

function term(io::IO, keyword::Keyword)
    if keyword.key in DocumentInfoKeywords
        printstyled(io, "#+", keyword.key, ": ", color=:light_black)
        printstyled(io, keyword.value, color=:magenta)
    else
        printstyled(io, "#+", keyword.key, ": ", keyword.value, color=:light_black)
    end
end

function term(io::IO, ::Org, env::LaTeXEnvironment, indent::Integer=0)
    printstyled(io, ' '^indent, "\\begin", color=:light_blue)
    print(io, '{')
    printstyled(io, env.name, color=:magenta)
    print(io, '}')
    printstyled(io, env.contents[1], '\n', color=:light_blue)
    for line in env.contents[2:end]
        printstyled(io, ' '^(2+indent), line, '\n', color=:light_magenta)
    end
    printstyled(io, ' '^indent, "\\end", color=:light_blue)
    print(io, '{')
    printstyled(io, env.name, color=:magenta)
    print(io, '}')
end

term(io::IO, node::NodeProperty) =
    print(io, ':', node.name, if node.additive "+:" else ":" end, node.value)

function term(io::IO, o::Org, objs::Vector{OrgObject})
    for obj in objs
        term(io, o, obj)
    end
end

function term(io::IO, o::Org, par::Paragraph, indent::Integer=0)
    contentbuf = IOContext(IOBuffer(), :color => get(io, :color, false))
    term(contentbuf, o, par.contents)
    contents = String(take!(contentbuf.io))
    lines = wraplines(contents, displaysize(io)[2] - indent)
    for line in lines
        print(io, ' '^indent, line)
        line === last(lines) || print(io, '\n')
    end
end

# Table Row

# ---------------------
# Objects
# ---------------------

# Terminal styling

termstyle(code::String) = if !get(stdout, :color, false)
    ""
else
    "\e[$(code)m"
end

termstyle(codes::Vector{String}) = if !get(stdout, :color, false)
    ""
else
    if length(codes) > 0
        string("\e[0;", join(codes, ';'), "m")
    else
        "\e[0m"
    end
end

term(io::IO, o::Org, obj::OrgObject, _::Vector{String}) =
    term(io::IO, o::Org, obj::OrgObject)
term(io::IO, obj::OrgObject, _::Vector{String}) =
    term(io::IO, obj::OrgObject)

# Now onto the objects

term(io::IO, entity::Entity) = print(io, Entities[entity.name].utf8)

function term(io::IO, latex::LaTeXFragment)
    if isnothing(latex.delimiters)
        printstyled(io, latex.contents, color=:magenta)
    else
        printstyled(io, latex.delimiters[1], latex.contents,
                    latex.delimiters[2], color=:magenta)
    end
end

term(::IO, ::ExportSnippet) = nothing

const FootnoteUnicodeSuperscripts =
    Dict('1' => '¹',
         '2' => '²',
         '3' => '³',
         '4' => '⁴',
         '5' => '⁵',
         '6' => '⁶',
         '7' => '⁷',
         '8' => '⁸',
         '9' => '⁹',
         '0' => '⁰')

function term(io::IO, o::Org, fn::FootnoteReference)
    if haskey(o.footnotes, something(fn.label, fn))
        index = o.footnotes[something(fn.label, fn)][1]
        printstyled(io, join([FootnoteUnicodeSuperscripts[c] for c in string(index)]);
            color=:yellow)
    else
        printstyled(io, "[#undefined#]", color=:yellow)
    end
end

function term(io::IO, o::Org, keycite::CitationReference)
    term(io, o, keycite.prefix)
    printstyled(io, '@', keycite.key, bold=true, color=:magenta)
    term(io, o, keycite.suffix)
end

function term(io::IO, o::Org, cite::Citation)
    printstyled(io, "[", color=:magenta)
    # if !isnothing(cite.style[1])
    #     printstyled(io, '/', cite.style[1], color=:blue)
    # end
    # if !isnothing(cite.style[2])
    #     printstyled(io, '/', cite.style[2], color=:light_blue)
    # end
    # printstyled(io, ':', color=:light_black)
    if !isnothing(cite.globalprefix)
        term(io, o, cite.globalprefix)
        printstyled(io, ';', color=:light_magenta)
    end
    for keycite in cite.citerefs
        term(io, o, keycite)
        keycite === last(cite.citerefs) || printstyled(io, ';', color=:light_magenta)
    end
    if !isnothing(cite.globalsuffix)
        printstyled(io, ';', color=:light_magenta)
        term(io, o, cite.globalsuffix)
    end
    printstyled(io, ']', color=:magenta)
end

term(::IO, ::InlineBabelCall) = nothing

function term(io::IO, src::InlineSourceBlock)
    printstyled(io, src.body, color=:light_cyan)
end

term(io::IO, ::LineBreak) = print(io, '\n')

const term_stylecodes_link = ["4", "34"]

function term(io::IO, link::RadioLink, stylecodes::Vector{String}=String[])
    print(io, termstyle(term_stylecodes_link))
    for obj in link.radio.contents
        term(io, obj, [stylecodes; term_stylecodes_link])
    end
    print(io, termstyle(stylecodes))
end

const link_uri_schemes =
    Dict("https" => p -> "https://$p",
         "file" => p -> "file://$(abspath(p))")

function term(io::IO, path::LinkPath)
    if path.protocol in keys(link_uri_schemes)
        pathuri = link_uri_schemes[path.protocol](path.path)
        print(io, "\e]8;;", pathuri, "\e\\")
        "\e[0;31mꜛ\e[0;0m\e]8;;\e\\"
    else
        ""
    end
end

function term(io::IO, link::AngleLink, stylecodes::Vector{String}=String[])
    print(io, termstyle(term_stylecodes_link))
    pathlink = term(io, link.path)
    print(io, '<', string(link.path), '>')
    print(io, pathlink, termstyle(stylecodes))
end

function term(io::IO, link::RegularLink, stylecodes::Vector{String}=String[])
    print(io, termstyle(term_stylecodes_link))
    pathlink = term(io, link.path)
    if isnothing(link.description) || length(link.description) == 0
        print(io, string(link.path))
    else
        for obj in link.description
            term(io, obj, [stylecodes; term_stylecodes_link])
        end
    end
    print(io, pathlink, termstyle(stylecodes))
end

function term(io::IO, o::Org, mac::Macro)
    expanded = macroexpand(o, mac)
    if isnothing(expanded)
        printstyled(io, "{{{", mac.name, '(', join(mac.arguments, ","), ")}}}", color=:light_black)
    else
        term.(Ref(io), parseorg(expanded, OrgObjectMatchers, OrgObjectFallbacks))
    end
end

function term(io::IO, radio::RadioTarget, stylecodes::Vector{String}=String[])
    print(io, termstyle("4"))
    for obj in radio.contents
        term(io, obj, [stylecodes; "4"])
    end
    print(io, termstyle(stylecodes))
end

term(::IO, ::Target) = nothing

term(io::IO, statscookie::StatisticsCookiePercent) =
    printstyled(io, '[', statscookie.percentage, "%]",
                color=if statscookie.percentage == "100"; :light_black else :green end)
term(io::IO, statscookie::StatisticsCookieFraction) =
    printstyled(io, '[', if !isnothing(statscookie.complete) string(statscookie.complete) else "" end,
                '/', if !isnothing(statscookie.total) string(statscookie.total) else "" end, ']',
                color=if statscookie.complete == statscookie.total; :light_black else :green end)

term(io::IO, script::Superscript) = print(io, script.char, '^', script.script)
term(io::IO, script::Subscript) = print(io, script.char, '_', script.script)

term(io::IO, cell::TableCell) = printstyled(io, "| ", cell.contents, " |", color=:magenta)

function term(io::IO, tsrod::TimestampRepeaterOrDelay)
    timeunits = Dict('h' => "hour",
                     'd' => "day",
                     'w' => "week",
                     'm' => "month",
                     'y' => "year")
    if tsrod.type in (:cumulative, :catchup, :restart)
        printstyled(io, "every ", tsrod.value, ' ', timeunits[tsrod.unit],
                    if tsrod.value == 1 "" else 's' end, " thereafter",
                    color=:light_yellow)
    else
        printstyled(io, "warning ", tsrod.value, ' ', timeunits[tsrod.unit],
                    if tsrod.value == 1 "" else 's' end, " before",
                    color=:light_yellow)
    end
end

term(io::IO, tsd::TimestampDiary) = print(io, "<%%", tsd.sexp, '>')

function term(io::IO, ts::TimestampInstant)
    if !isnothing(ts.time)
        printstyled(io, hour(ts.time), ':', minute(ts.time), ' ', color=:yellow)
    end
    printstyled(io, Dates.format(ts.date, dateformat"e d u Y"), color=:yellow)
    if !isnothing(ts.repeater)
        printstyled(io, " and ", color=:light_yellow)
        term(io, ts.repeater)
    end
    if !isnothing(ts.warning)
        print(io, ' ')
        term(io, ts.warning)
    end
end

function term(io::IO, tsr::TimestampRange)
    if tsr.start.date == tsr.stop.date &&
        tsr.start.repeater == tsr.stop.repeater
        printstyled(io, tsr.start.date, ' ', dayabbr(tsr.start.date), color=:yellow)
        printstyled(io, ' ', hour(tsr.start.time), ':', minute(tsr.start.time),
                    " – ", hour(tsr.stop.time), ':', minute(tsr.stop.time), color=:yellow)
        if !isnothing(tsr.start.repeater)
            printstyled(io, " and ", color=:light_yellow)
            term(io, tsr.start.repeater)
        end
        if !isnothing(tsr.start.warning)
            print(io, ' ')
            term(io, tsr.start.warning)
        end
    else
        term(io, tsr.start)
        printstyled(io, " – ", color=:yellow)
        term(io, tsr.stop)
    end
end

const markup_term_codes =
    Dict(:bold => "1",
         :italic => "3",
         :strikethrough => "9",
         :underline => "4",
         :verbatim => "32", # green
         :code => "36") # cyan

function term(io::IO, markup::TextMarkup, stylecodes::Vector{String}=String[])
    markuptermcode = markup_term_codes[markup.formatting]
    print(io, termstyle(markuptermcode))
    if markup.contents isa AbstractString
        print(io, markup.contents)
    else
        for obj in markup.contents
            term(io, obj, [stylecodes; markuptermcode])
        end
    end
    print(io, termstyle(stylecodes))
end

function term(io::IO, text::TextPlain)
    tsub = replace(replace(replace(replace(text.text,
                                           "..." => "…"),
                                   r"---([^-])" => s"—\1"),
                           r"--([^-])" => s"–\1"),
                   r"\\-" => "-")
    print(io, tsub)
end

# ---------------------
# Catchall
# ---------------------

function term(io::IO, component::OrgComponent)
    @warn "No method for converting $(typeof(component)) to a term representation currently exists"
    print(io, component, '\n')
end
