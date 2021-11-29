function Base.string(component::Union{Org, OrgComponent})
    b = IOBuffer()
    org(b, component)
    String(take!(b))
end

function org(io::IO, o::Org)
    for component in o.contents
        (component isa Heading && component !== first(o.contents)) && print(io, '\n')
        org(io, component)
        component === last(o.contents) || print(io, '\n')
    end
    print(io, '\n')
end

function org(io::IO, component::OrgComponent, indent::Integer)
    print(io, ' '^indent)
    org(io, component)
end

org(o::Union{Org, OrgComponent}) = org(stdout, o)

function org(_::IO, component::C) where { C <: OrgComponent}
    @warn "No method for converting $C to a string representation currently exists"
end

# ---------------------
# Sections
# ---------------------

function org(io::IO, heading::Heading, indent::Integer=0)
    print(io, ' '^indent)
    print(io, '*'^heading.level, ' ')
    if !isnothing(heading.keyword)
        print(io, heading.keyword, ' ')
    end
    if !isnothing(heading.priority)
        print(io, "[#", heading.priority, "] ")
    end
    print(io, heading.title)
    if length(heading.tags) > 0
        print(io, " :", join(heading.tags, ':'), ":")
    end
    if !isnothing(heading.planning)
        print(io, '\n')
        org(io, heading.planning, indent)
    end
    if !isnothing(heading.properties)
        print(io, '\n')
        org(io, heading.properties, indent)
    end
    if !isnothing(heading.section)
        print(io, "\n\n")
        org(io, heading.section, indent)
    end
end

function org(io::IO, section::Section, indent::Integer=0)
    for component in section.contents
        org(io, component, indent)
        component === last(section.contents) || print(io, '\n')
    end
end

# ---------------------
# Greater Elements
# ---------------------

# Greater Block

function org(io::IO, drawer::Drawer, indent::Integer=0)
    print(io, ' '^indent, ':', drawer.name, ":\n")
    for node in drawer.contents
        org(io, node, indent)
        print(io, '\n')
    end
    print(io, ' '^indent, ":END:")
end

# Dynamic Block
# FootnoteDef
# InlineTask

function org(io::IO, item::Item, indent::Integer=0, offset::Integer=0)
    print(io, ' '^indent, item.bullet)
    offset += length(item.bullet)
    if !isnothing(item.counterset)
        print(io, " [@", item.counterset, "]")
        offset += length(item.counterset) + 4
    end
    if !isnothing(item.checkbox)
        print(io, " [", item.checkbox, ']')
        offset += 4
    end
    if !isnothing(item.tag)
        print(io, item.tag, " ::")
        offset += length(item.tag) + 3
    end
    if !isnothing(item.contents)
        print(io, ' ')
        offset += 1
        contents = string(Paragraph(item.contents))
        lines = wraplines(contents, displaysize(io)[2] - indent, offset)
        for line in lines
            print(io, line)
            line === last(lines) || print(io, '\n', ' '^(indent+2))
        end
    end
    if !isnothing(item.sublist)
        org(io, item.sublist, indent + 2)
    end
end

function org(io::IO, list::List, indent::Integer=0)
    for item in list.items
        org(io, item, indent)
        item === last(list.items) || print(io, '\n')
    end
end

function org(io::IO, propdrawer::PropertyDrawer, indent::Integer=0)
    print(io, ' '^indent, ":PROPERTIES:\n")
    for node in propdrawer.contents
        org(io, node, indent)
        print(io, '\n')
    end
    print(io, ' '^indent, ":END:")
end

const table_charset_org =
    Dict('|' => '|',
         '>' => '|',
         '<' => '|',
         '[' => ' ',
         ']' => ' ',
         '-' => '-',
         '+' => '+')

org(io::IO, table::Table, indent::Integer=0) = layouttable(io, table, table_charset_org, indent)

# ---------------------
# Elements
# ---------------------

org(io::IO, bcall::BabelCall) = print(io, "#+call: ", bcall.name)

function org(io::IO, block::Block)
    name, data = if block isa CommentBlock
        ("comment", nothing)
    elseif block isa VerseBlock
        ("verse", nothing)
    elseif block isa ExampleBlock
        ("example", nothing)
    elseif block isa ExportBlock
        ("example", block.backend)
    elseif block isa SourceBlock
        ("src", if isnothing(block.arguments)
             block.lang
         else
             string(block.lang, " ", block.arguments)
         end)
    elseif block isa CustomBlock
        (block.name, block.data)
    end
    print(io, "#+begin_", name)
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
    print(io, "#+end_", name)
end

# Clock

# DiarySexp

function org(io::IO, planning::Planning)
    values = [(type, getproperty(planning, type))
              for type in (:deadline, :scheduled, :closed)] |>
                  vals -> filter(v -> !isnothing(v[2]), vals)
    for val in values
        print(io, uppercase(string(val[1])), ' ')
        org(io, val[2])
        val === last(values) || print(io, ' ')
    end
end

function org(io::IO, comment::Comment, indent::Integer=0)
    for line in comment.contents
        print(io, ' '^indent, "# ", line)
        line === last(comment.contents) || print(io, '\n')
    end
end

function org(io::IO, fw::FixedWidth, indent::Integer=0)
    for line in fw.contents
        print(io, ' '^indent, ": ", line)
        line === last(fw.contents) || print(io, '\n')
    end
end

org(io::IO, ::HorizontalRule) = print(io, "-----")

org(io::IO, keyword::Keyword) = print(io, "#+", keyword.key, ": ", keyword.value)

function org(io::IO, env::LaTeXEnvironment, indent::Integer=0)
    print(io, ' '^indent, "\begin{", env.name, "}\n")
    for line in env.contents
        print(io, ' '^indent, line)
        line === last(env.contents) || print(io, '\n')
    end
    print(io, ' '^indent, "\end{", env.name, "}")
end

org(io::IO, node::NodeProperty) =
    print(io, ':', node.name, if node.additive "+:" else ":" end, node.value)

function Base.string(par::Paragraph)
    b = IOBuffer()
    for obj in par.contents
        org(b, obj)
    end
    String(take!(b))
end

function org(io::IO, par::Paragraph, indent::Integer=0)
    lines = wraplines(string(par), displaysize(io)[2] - indent)
    for line in lines
        print(io, ' '^indent, line)
        line === last(lines) || print(io, '\n')
    end
end

# Table Row

org(::IO, ::EmptyLine, _::Integer=0) = nothing

# ---------------------
# Objects
# ---------------------

org(io::IO, entity::Entity) = print(io, '\\', entity.name, entity.post)

function org(io::IO, latex::LaTeXFragment)
    if isnothing(latex.delimiters)
        print(io, latex.delimiters[1], latex.contents, latex.delimiters[2])
    else
        print(io. latex.contents)
    end
end

org(io::IO, snippet::ExportSnippet) =
    print(io, "@@", snippet.backend, ':', snippet.snippet, "@@")

# Footnote Ref

function org(io::IO, bcall::InlineBabelCall)
    print(io, "call_", bcall.name)
    if !isnothing(bcall.header)
        print(io, '[', bcall.header, ']')
    end
    print(io, '(', bcall.arguments, ')')
end

function org(io::IO, src::InlineSourceBlock)
    print(io, "src_", src.lang)
    if !isnothing(src.options)
        print(io, '[', src.options, ']')
    end
    print(io, '{', src.body, '}')
end

org(io::IO, ::LineBreak) = print(io, "\\\\\n")

const link_protocol_prefixes =
    Dict(:coderef => p -> "($p)",
         :custom_id => p -> "#$p",
         :heading => p -> "*$p",
         :fuzzy => identity)

function org(io::IO, path::LinkPath)
    if path.protocol isa AbstractString
        print(io, path.protocol, ':', path.path)
    elseif path.protocol in keys(link_protocol_prefixes)
        print(io, link_protocol_prefixes[path.protocol](path.path))
    else
        print(io, path.protocol, ':', path.path)
    end
end

function org(io::IO, link::Link)
    print(io, "[[")
    org(io, link.path)
    if isnothing(link.description)
        print(io, "]]")
    else
        print(io, ']', link.description, "]]")
    end
end

org(io::IO, mac::Macro) = print(io, "{{{", mac.name, '(', join(mac.arguments, ","), ")}}}")

function org(io::IO, radio::RadioTarget)
    print(io, "<<<")
    org.(Ref(io), radio.contents)
    print(io, ">>>")
end

org(io::IO, target::Target) = print(io, "<<", target.target, ">>")

org(io::IO, statscookie::StatisticsCookiePercent) =
    print(io, '[', statscookie.percentage, "%]")
org(io::IO, statscookie::StatisticsCookieFraction) =
    print(io, '[', if !isnothing(statscookie.complete) string(statscookie.complete) else "" end,
          '/', if !isnothing(statscookie.total) string(statscookie.total) else "" end, ']')

org(io::IO, script::Superscript) = print(io, script.char, '^', script.script)
org(io::IO, script::Subscript) = print(io, script.char, '_', script.script)

org(io::IO, cell::TableCell) = print(io, "| ", cell.contents, " |")

org(io::IO, tsrod::TimestampRepeaterOrDelay) = print(io, tsrod.mark, tsrod.value, tsrod.unit)

org(io::IO, tsd::TimestampDiary) = print(io, "<%%", tsd.sexp, '>')

function org(io::IO, ts::TimestampInstant)
    bra, ket = if ts isa TimestampActive; ('<', '>') else ('[', ']') end
    print(io, bra)
    print(io, ts.date, ' ', dayabbr(ts.date))
    if !isnothing(ts.time)
        print(io, ' ', hour(ts.time), ':', minute(ts.time))
    end
    if !isnothing(ts.repeater)
        print(io, ' ')
        org(io, ts.repeater)
    end
    print(io, ket)
end

function org(io::IO, tsr::TimestampRange)
    if tsr.start.date == tsr.stop.date &&
        tsr.start.repeater == tsr.stop.repeater
        bra, ket = if tsr isa TimestampActiveRange; ('<', '>') else ('[', ']') end
        print(io, bra)
        print(io, tsr.start.date, ' ', dayabbr(tsr.start.date))
        print(io, ' ', hour(tsr.start.time), ':', minute(tsr.start.time),
              '-', hour(tsr.stop.time), ':', minute(tsr.stop.time))
        if !isnothing(tsr.start.repeater)
            print(io, ' ')
            org(io, tsr.start.repeater)
        end
        print(io, ket)
    else
        org(io, tsr.start)
        print(io, "--")
        org(io, tsr.stop)
    end
end

org(io::IO, text::TextPlain) = print(io, text.text)

function org(io::IO, markup::TextMarkup)
    print(io, markup.pre, markup.marker)
    if markup.contents isa AbstractString
        print(io, markup.contents)
    else
        org.(Ref(io), markup.contents)
    end
    print(io, markup.marker, markup.post)
end
