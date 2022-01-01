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
    term(io, o.contents, indent)
end

function term(io::IO, components::Vector{<:OrgComponent}, indent::Integer=2)
    for component in components
        (component isa Heading && component !== first(components)) && print(io, '\n')
        term(io, component, indent)
        component === last(components) || print(io, '\n')
    end
end

function term(io::IO, component::OrgComponent, indent::Integer)
    print(io, ' '^indent)
    term(io, component)
end

term(o::Union{Org, OrgComponent}) = term(stdout, o, 2)
term(p::Paragraph) = (term(stdout, p, 2); print('\n'))
term(o::OrgObject) = (term(stdout, o, 2); print('\n'))

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
        printstyled(heading.keyword, ' ', color=kcolor)
    end
    if !isnothing(heading.priority)
        printstyled(io, "[#", heading.priority, "] ", color=:light_red)
    end
    if get(stdout, :color, false)
        for obj in heading.title
            if obj isa TextMarkup || obj isa TextPlain
                term(io, obj, "\e[1;34m")
            else
                term(io, obj)
            end
        end
    else
        org.(Ref(io), heading.title)
    end
    if length(heading.tags) > 0
        printstyled(" :", join(heading.tags, ":"), ":", color=:light_black)
    end
end

function tableofcontents(io::IO, org::Org, depthrange::UnitRange=1:9, indent::Integer=2)
    function printheading(h)
        if h.level in depthrange
            print(io, ' '^indent)
            termheadingonly(io, h)
            print(io, '\n')
        end
    end
    filtermap(org, [Heading], printheading)
    nothing
end

tableofcontents(io::IO, org::Org, depth::Integer, indent::Integer=2) =
    tableofcontents(io, org, depth:depth, indent)

tableofcontents(org::Org, depth) = tableofcontents(stdout, org, depth)

function term(io::IO, heading::Heading, indent::Integer=0)
    print(io, ' '^indent)
    termheadingonly(io, heading)
    if !isnothing(heading.planning)
        print(io, '\n')
        term(io, heading.planning, indent)
    end
    # Don't show properties
    if !isnothing(heading.section)
        print(io, "\n\n")
        term(io, heading.section, indent)
    end
end

function term(io::IO, section::Section, indent::Integer=0)
    for component in section.contents
        term(io, component, indent)
        component === last(section.contents) || print(io, '\n')
    end
end

# ---------------------
# Greater Elements
# ---------------------

# Greater Block

function term(io::IO, drawer::Drawer, indent::Integer=0)
    for component in drawer.contents
        term(io, component, indent)
        component === last(drawer.contents) || print(io, '\n')
    end
end

# Dynamic Block
# FootnoteDef
# InlineTask

function term(io::IO, item::Item, unordered::Bool=true, indent::Integer=0, depth::Integer=0)
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
        printstyled(io, ' ', item.tag, "::", color=:blue)
        offset += length(item.tag) + 3
    end
    if length(item.contents) > 0
        print(io, ' ')
        offset += 1
        contentbuf = IOContext(IOBuffer(), :color => get(io, :color, false),
                               :displaysize => (displaysize(io)[1],
                                                displaysize(io)[2] - indent - 2))
        parlines = if item.contents[1] isa Paragraph
            for obj in item.contents[1]; term(contentbuf, obj) end
            contents = String(take!(contentbuf.io))
            wraplines(contents, displaysize(io)[2] - indent - 2, offset)
        else
            ["\n"]
        end
        components = @view item.contents[if item.contents[1] isa Paragraph 2 else 1 end:end]
        for component in components
            term(contentbuf, component, indent)
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

function term(io::IO, list::List, indent::Integer=0, depth=0)
    for item in list.items
        term(io, item, list isa UnorderedList, indent, depth)
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

term(io::IO, table::Table, indent::Integer=0) =
    layouttable(io, table, table_charset_boxdraw, indent)

# ---------------------
# Elements
# ---------------------

term(::IO, ::BabelCall) = nothing

function printblockcontent(io, prefix::AbstractString, prefixcolor::Symbol, lines::Vector{<:AbstractString}, contentcolor::Symbol=:default)
    printstyled(io, prefix, color=prefixcolor)
    if length(lines) > 0
        printstyled(lines[1], color=contentcolor)
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

term(io::IO, block::ExampleBlock, indent::Integer=0) =
    printblockcontent(io, ' '^indent * "║ ", :light_black, block.contents, :cyan)

function term(io::IO, srcblock::SourceBlock, indent::Integer=0)
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

function term(io::IO, planning::Planning)
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

function term(io::IO, env::LaTeXEnvironment, indent::Integer=0)
    printstyled(io, ' '^indent, "\begin{", env.name, "}\n", color=:light_magenta)
    for line in env.contents
        printstyled(io, ' '^indent, line, color=:light_magenta)
        line === last(env.contents) || print(io, '\n')
    end
    printstyled(io, ' '^indent, "\end{", env.name, "}", color=:light_magenta)
end

term(io::IO, node::NodeProperty) =
    print(io, ':', node.name, if node.additive "+:" else ":" end, node.value)

function term(io::IO, par::Paragraph, indent::Integer=0)
    contentbuf = IOContext(IOBuffer(), :color => get(io, :color, false))
    for obj in par.contents
        term(contentbuf, obj)
    end
    contents = String(take!(contentbuf.io))
    lines = wraplines(contents, displaysize(io)[2] - indent)
    for line in lines
        print(io, ' '^indent, line)
        line === last(lines) || print(io, '\n')
    end
end

# Table Row

term(::IO, ::EmptyLine, _::Integer=0) = nothing

# ---------------------
# Objects
# ---------------------

term(io::IO, entity::Entity) = print(io, Entities[entity.name].utf8, entity.post)

function term(io::IO, latex::LaTeXFragment)
    if isnothing(latex.delimiters)
        printstyled(io, latex.contents, color=:magenta)
    else
        printstyled(io, latex.delimiters[1], latex.contents,
                    latex.delimiters[2], color=:magenta)
    end
end

term(::IO, ::ExportSnippet) = nothing

# Footnote Ref

term(::IO, ::InlineBabelCall) = nothing

function term(io::IO, src::InlineSourceBlock)
    printstyled(io, src.body, color=:light_cyan)
end

term(io::IO, ::LineBreak) = print(io, '\n')

const link_uri_schemes =
    Dict("https" => p -> "https://$p",
         "file" => p -> "file://$(abspath(p))")

function term(io::IO, link::Link)
    pathstr = string(link.path)
    if link.path.protocol in keys(link_uri_schemes)
        pathuri = link_uri_schemes[link.path.protocol](link.path.path)
        if isnothing(link.description)
            print(io, "\e]8;;$pathuri\e\\\e[4;34m$pathstr\e[0;0m\e]8;;\e\\")
        else
            print(io, "\e]8;;$pathuri\e\\\e[4;34m$(link.description)\e[0;0m\e]8;;\e\\")
        end
    else
        print(io, "\e[4;34m", "[[$pathstr]",
              if isnothing(link.description) "" else
                  "[$(link.description)]" end,
              "]", "\e[0;0m")
    end
end

function term(io::IO, mac::Macro)
    if mac.name == "results" && length(mac.arguments) == 1
        term.(Ref(io), parse(Paragraph, mac.arguments[1]).contents)
    elseif mac.name == "results" && length(mac.arguments) == 0
        nothing
    else
        print(io, "{{{", mac.name, '(', join(mac.arguments, ","), ")}}}")
    end
end

function term(io::IO, radio::RadioTarget)
    term.(Ref(io), radio.contents)
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
    Dict(:bold => "\e[1m",
         :italic => "\e[3m",
         :strikethrough => "\e[9m",
         :underline => "\e[4m",
         :verbatim => "\e[32m", # green
         :code => "\e[36m") # cyan

function term(io::IO, markup::TextMarkup, accumulatedmarkup::String="")
    color = get(stdout, :color, false)
    print(io, markup.pre)
    if color && markup.type in keys(markup_term_codes)
        accumulatedmarkup *= markup_term_codes[markup.type]
    end
    if markup.contents isa AbstractString
        print(io, accumulatedmarkup, markup.contents,
              if color "\e[0;0m" else "" end)
    else
        for obj in markup.contents
            if obj isa TextMarkup || obj isa TextPlain
                term(io, obj, accumulatedmarkup)
            else
                term(io, obj)
            end
        end
    end
    print(io, markup.post)
end

function term(io::IO, text::TextPlain, accumulatedmarkup::String="")
    tsub = replace(replace(replace(replace(text.text,
                                           "..." => "…"),
                                   r"---([^-])" => s"—\1"),
                           r"--([^-])" => s"–\1"),
                   r"\\-" => "-")
    if get(stdout, :color, false)
        print(io, accumulatedmarkup, tsub, "\e[0;0m")
    else
        print(io, tsub)
    end
end

# ---------------------
# Catchall
# ---------------------

function term(io::IO, component::OrgComponent)
    @warn "No method for converting $(typeof(component)) to a term representation currently exists"
    print(io, component, '\n')
end
