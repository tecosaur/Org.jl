Base.show(io::IO, ::MIME"text/markdown", markdown::OrgDoc) = (markdown(io, markdown), nothing)

function markdown(io::IO, o::OrgDoc)
    for component in o.contents
        markdown(io, component)
    end
end

markdown(o::Union{OrgDoc, Component}) = markdown(stdout, o)

markdown(io::IO, c::Component) = html(io, c)

function markdown(io::IO, heading::Heading)
    print(io, '#'^(heading.level + 1), ' ')
    if !isnothing(heading.keyword)
        print(io, heading.keyword, ' ')
    end
    if !isnothing(heading.priority)
        print(io, "[#", heading.priority, "] ")
    end
    markdown.(Ref(io), heading.title)
    print(io, '\n')
    if !isnothing(heading.section)
        print(io, '\n')
        markdown(io, heading.section)
    end
end

function markdown(io::IO, section::Section)
    for component in section.contents
        markdown(io, component)
        component === last(section.contents) || print(io, "\n\n")
    end
    print(io, '\n')
end

function markdown(io::IO, afkw::AffiliatedKeywordsWrapper)
    @nospecialize afkw
    markdown(io, afkw.element)
end

# ---------------------
# Greater Elements
# ---------------------

function markdown(io::IO, specialblock::SpecialBlock)
    print(io, "!!! ", specialblock.name)
    if !isnothing(specialblock.parameters)
        print(io, ' ', specialblock.parameters)
    end
    println(io)
    content = join(sprint.(markdown, specialblock.contents), '\n')
    for line in split(content, '\n')
        print(io, "    ", line, '\n')
    end
end

function markdown(io::IO, centerb::CenterBlock)
    print(io, "<div style=\"text-align: center; margin: auto;\">\n")
    for el in centerb.contents
        markdown(io, el)
        print(io, '\n')
    end
    print(io, "</div>\n")
end

function markdown(io::IO, quoteb::QuoteBlock)
    content = join(sprint.(markdown, quoteb.contents), '\n')
    for line in split(content, '\n')
        print(io, "> ", line, '\n')
    end
end

function markdown(io::IO, drawer::Drawer)
    for el in drawer.contents
        markdown(io, el)
        el === last(drawer.contents) || print(io, '\n')
    end
end

function markdown(io::IO, dynblock::DynamicBlock)
    for el in dynblock.contents
        markdown(io, el)
        el === last(dynblock.contents) || print(io, '\n')
    end
end

function markdown(io::IO, fn::FootnoteDefinition)
    print(io, "[^", replace(fn.label, r"[^A-Za-z0-9]" => ""), "]:\n\n")
    content = join(sprint.(markdown, fn.definition), '\n')
    for line in split(content, '\n')
        print(io, "    ", line, '\n')
    end
end

# InlineTask

function markdown(io::IO, item::Item, indent::Integer=0, offset::Integer=0)
    print(io, ' '^indent,
          if item.bullet in ("+", "-", "*")
              '-' else item.bullet end)
    offset += length(item.bullet) + 1
    if !isnothing(item.counterset)
        print(io, " [@", item.counterset, "]")
        offset += length(item.counterset) + 4
    end
    if !isnothing(item.checkbox)
        print(io, " [", item.checkbox, ']')
        offset += 4
    end
    if !isnothing(item.tag)
        tagbuf = IOContext(IOBuffer(), :color => get(io, :color, false),
                           :displaysize => (displaysize(io)[1],
                                            displaysize(io)[2] - indent - 2))
        for obj in item.tag
            markdown(tagbuf, obj)
        end
        taglines = wraplines(String(take!(tagbuf.io)),
                             displaysize(io)[2] - indent - 2, offset)
        for line in taglines
            print(io, line)
            line === last(taglines) || print(io, '\n', ' '^(indent+2))
        end
        print(io, " ::")
        offset += length(taglines[end]) + 3
    end
    if length(item.contents) > 0
        print(io, ' ')
        offset += 1
        contentbuf = IOContext(IOBuffer(), :color => get(io, :color, false),
                               :displaysize => (displaysize(io)[1],
                                                displaysize(io)[2] - indent - 2))
        cindent = indent + textwidth(item.bullet) + 1
        parlines = if item.contents[1] isa Paragraph
            for obj in item.contents[1]; markdown(contentbuf, obj) end
            contents = String(take!(contentbuf.io))
            wraplines(contents, displaysize(io)[2] - cindent, offset)
        else
            [""]
        end
        components = @view item.contents[if item.contents[1] isa Paragraph 2 else 1 end:end]
        for component in components
            markdown(contentbuf, component, indent)
            component === last(components) || print(contentbuf, '\n')
        end
        otherlines = split(String(take!(contentbuf.io)), '\n')
        lines = vcat(parlines, if otherlines == [""]; [] else otherlines end)
        for line in lines
            print(io, line)
            line === last(lines) || print(io, '\n', ' '^cindent)
        end
    end
end

function markdown(io::IO, list::List, indent::Integer=0)
    @nospecialize list
    for item in list.items
        markdown(io, item, indent)
        item === last(list.items) || print(io, '\n')
    end
end

markdown(::IO, ::PropertyDrawer) = nothing

const table_charset_markdown =
    Dict('|' => '|',
         '>' => '|',
         '<' => '|',
         '[' => ' ',
         ']' => ' ',
         '-' => '-',
         '+' => '|')

markdown(io::IO, table::Table) =
    layouttable(io, markdown, table, table_charset_markdown, 0)

# ---------------------
# Elements
# ---------------------

markdown(::IO, ::BabelCall) = nothing

markdown(::IO, ::CommentBlock) = nothing

function markdown(io::IO, block::ExampleBlock)
    print(io, "```\n",
          join(block.contents, '\n'),
          "\n```")
end

function markdown(io::IO, block::SourceBlock)
    print(io, "```", block.lang, "\n",
          join(block.contents, '\n'),
          "\n```")
end

# Block
# Clock
# Planning
# DiarySexp

markdown(::IO, ::Comment) = nothing

function markdown(io::IO, fw::FixedWidth)
    print(io, "```\n",
          join(fw.contents, '\n'),
          "\n```")
end

markdown(io::IO, ::HorizontalRule) = print(io, "---")

function markdown(io::IO, keyword::Keyword)
    if keyword.key == "title"
        print(io, "# ", keyword.value)
    elseif keyword.key == "subtitle"
        print(io, "### ", keyword.value)
    elseif keyword.key in ("author", "date")
        print(io, "By ", keyword.value)
    end
end

function markdown(io::IO, env::LaTeXEnvironment)
    print(io, "\$\$\n\\begin{", env.name, "}\n",
          join(env.contents, '\n'),
          "\n\\end{", env.name, "}\n\$\$")
end

# Node Property

function markdown(io::IO, par::Paragraph)
    for obj in par.contents
        markdown(io, obj)
    end
end

markdown(io::IO, entity::Entity) = print(io, Entities[entity.name].utf8)

markdown(io::IO, latex::LaTeXFragment) =
    print(io, "\$", latex.contents, "\$")

markdown(io::IO, snippet::ExportSnippet) =
    if snippet.backend == "markdown" print(io, snippet.snippet) end

function markdown(io::IO, fn::FootnoteReference)
    label = replace(something(fn.label, string(rand(UInt32), base=36)),
                    r"[^A-Za-z0-9]" => "")
    print(io, "[^", label, "]")
    if !isnothing(fn.definition)
        print(io, '\n')
        markdown(io, FootnoteDefinition(
            SubString(label), Element[Paragraph(fn.definition)]))
        print(io, '\n')
    end
end

function markdown(io::IO, keycite::CitationReference)
    foreach(p -> markdown(io, p), keycite.prefix)
    print(io, keycite.key)
    foreach(s -> markdown(io, s), keycite.suffix)
end

function markdown(io::IO, cite::Citation)
    foreach(p -> markdown(io, p), cite.globalprefix)
    for keycite in cite.citerefs
        markdown(io, keycite)
        keycite === last(cite.citerefs) || print(io, ", ")
    end
    foreach(s -> markdown(io, s), cite.globalsuffix)
end

markdown(::IO, ::InlineBabelCall) = nothing

markdown(io::IO, src::InlineSourceBlock) =
    print(io, "`", src.body, "`")

markdown(io::IO, ::LineBreak) = print(io, "\n")

markdown(io::IO, link::RadioLink) = markdown(io, link.radio)

const link_md_uri_schemes =
    Dict("https" => p -> "https://$p",
         "http" => p -> "http://$p",
         "file" => p -> if endswith(p, ".org")
             first(splitext(p)) * ".md"
         else p end)

function markdown(io::IO, path::LinkPath)
    if haskey(link_md_uri_schemes, path.protocol)
        pathuri = link_md_uri_schemes[path.protocol](path.path)
        print(io, pathuri)
    elseif path.protocol === :fuzzy
        print(io, path.path)
    elseif path.protocol isa String
        print(io, path.protocol, ':', path.path)
    end
end

function markdown_image(io::IO, path::LinkPath)
    print(io, "![image](", sprint(markdown, path), ")")
end

function markdown(io::IO, link::Union{PlainLink, AngleLink})
    if splitext(link.path.path)[end] in org_html_image_extensions
        markdown_image(io, link.path)
    else
        print(io, '[', sprint(markdown, link.path), "](",
              sprint(markdown, link.path), ')')
    end
end

function markdown(io::IO, link::RegularLink)
    if isnothing(link.description) || length(link.description) == 0
        if splitext(link.path.path)[end] in org_html_image_extensions
            markdown_image(io, link.path)
        else
            markdown(io, PlainLink(link.path))
        end
    else
        print(io, '[')
        foreach(o -> markdown(io, o), link.description)
        print(io, "](", sprint(markdown, link.path), ")")
    end
end

function markdown(io::IO, o::OrgDoc, mac::Macro)
    expanded = macroexpand(o, mac)
    if isnothing(expanded)
        print(io, "{{{", mac.name,
              '(', join(mac.arguments, ","), ")}}}")
    else
        foreach(o -> markdown(io, o),
                parseorg(expanded, org_object_matchers, org_object_fallbacks))
    end
end

function markdown(io::IO, target::RadioTarget)
    foreach(o -> markdown(io, o), target.contents)
end

function markdown(io::IO, cell::TableCell)
    foreach(o -> markdown(io, o), cell.contents)
end

const markdown_markup_codes =
    Dict(:bold => "**",
         :italic => "*",
         :underline => "__",
         :verbatim => "`",
         :code => "`",
         :strikethrough => "~~")


function markdown(io::IO, markup::TextMarkup)
    print(io, markdown_markup_codes[markup.formatting])
    if markup.contents isa SubString{String}
        print(io, markup.contents)
    else
        markdown.(Ref(io), markup.contents)
    end
    print(io, markdown_markup_codes[markup.formatting])
end

function markdown(io::IO, text::TextPlain)
    tsub = replace(text.text,
                   "..." => "…",
                   r"---([^-])" => s"—\1",
                   r"--([^-])" => s"–\1",
                   r"\\-" => "-")
    print(io, tsub)
end
