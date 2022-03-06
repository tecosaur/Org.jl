Base.show(io::IO, ::MIME"text/html", org::OrgDoc) = (html(io, org), nothing)

const html_entity_map =
    Dict('&' => "&amp;",
         '<' => "&lt;",
         '>' => "&gt;",
         '"' => "&quot;",
         '\'' => "&#39;",
         '/' => "&#x2F;",
         '`' => "&#x60;",
         '=' => "&#x3D;")

html_escape(s) = replace(s, r"[&<>\"'`=\/]" =>
    e -> html_entity_map[e[1]])

function html_tagpair(tag, attrs::Pair...)
    attrstr = if length(attrs) > 0
        ' ' * join(map(a -> string(a.first, "=\"", html_escape(a.second), '"'), attrs), ' ')
    else "" end
    (string('<', tag, attrstr, '>'), string("</", tag, '>'))
end

function html_tagwrap(s, tag, escape=false, attrs::Pair...)
    open, close = html_tagpair(tag, attrs...)
    string(open, if escape html_escape(s) else s end, close)
end
html_tagwrap(s, tag, attrs::Pair...) = html_tagwrap(s, tag, false, attrs...)

# ---------------------
# Org
# ---------------------

function html(io::IO, o::OrgDoc)
    for component in o.contents
        html(io, component)
        print(io, '\n')
    end
end


function html(_::IO, component::C) where { C <: OrgComponent}
    @warn "No method for converting $C to a html representation currently exists"
end
html(o::Union{OrgDoc, OrgComponent}) = html(stdout, o)

# ---------------------
# Sections
# ---------------------

function html(io::IO, heading::Heading)
    sopen, sclose = if isnothing(heading.section); ("", "")
    else ("<div class=\"sec$(heading.level)\">", "</div>") end
    print(io, sopen, "<h$(heading.level)>")
    if !isnothing(heading.keyword)
        print(io, html_tagwrap(heading.keyword, "span", true, "class" => "hkeyword"), ' ')
    end
    if !isnothing(heading.priority)
        print(io, html_tagwrap(heading.priority, "span", true, "class" => "hpriority"), ' ')
    end
    html.(Ref(io), heading.title)
    if length(heading.tags) > 0
        print.(io, html_tagwrap.(heading.tags, "span", true, "class" => "htag"))
    end
    print(io, "</h$(heading.level)>")
    if !isnothing(heading.section)
        print(io, "\n")
        html(io, heading.section)
    end
    print(io, sclose)
end

function html(io::IO, section::Section)
    for component in section.contents
        html(io, component)
        component === last(section.contents) || print(io, '\n')
    end
end

# ---------------------
# Greater Elements
# ---------------------

function html(io::IO, specialblock::SpecialBlock)
    for el in specialblock.contents
        html(io, el)
        el === last(specialblock.contents) || print(io, '\n')
    end
end

function html(io::IO, centerb::CenterBlock)
    print(io, "<div style=\"text-align: center; margin: auto;\">\n")
    for el in centerb.contents
        html(io, el)
        print(io, '\n')
    end
    print(io, "</div>\n")
end

function html(io::IO, quoteb::QuoteBlock)
    print(io, "<blockquote>\n")
    for el in quoteb.contents
        html(io, el)
        print(io, '\n')
    end
    print(io, "</blockquote>\n")
end

function html(io::IO, drawer::Drawer)
    for el in drawer.contents
        html(io, el)
        el === last(drawer.contents) || print(io, '\n')
    end
end

function html(io::IO, dynblock::DynamicBlock)
    for el in dynblock.contents
        html(io, el)
        el === last(dynblock.contents) || print(io, '\n')
    end
end

function html(io::IO, fn::FootnoteDefinition)
    print(io, "<p id=\"fn_$(html_escape(fn.label))\">",
          "[", html_escape(fn.label), "]: ")
    for el in fn.definition
        html(io, el)
        el === last(fn.definition) || print('\n')
    end
    print(io, "</p>")
end

# InlineTask

function html(io::IO, item::Item)
    open, close = if isnothing(item.tag)
        html_tagpair("li")
    else
        "<dt>", "</dd>"
    end
    print(io, open)
    # TODO support counterset
    if !isnothing(item.checkbox)
        print(io, "<input type=\"checkbox\" disabled",
              if item.checkbox == 'x'
                  " checked"
              elseif item.checkbox == ' '
                  ""
              else
                  " onload=\"this.indeterminate = true\""
              end, ">")
    end
    if !isnothing(item.tag)
        foreach(o -> html(io, o), item.tag)
        print(io, "</dt>\n<dd>")
    end
    if !isnothing(item.contents)
        foreach(el -> html(io, el), item.contents)
    end
    print(io, close)
end

function html(io::IO, list::List)
    open, close = html_tagpair(if list isa OrderedList; "ol" else "ul" end)
    print(io, open, '\n')
    for item in list.items
        html(io, item)
        print(io, '\n')
    end
    print(io, close)
end

html(::IO, ::PropertyDrawer) = nothing

function html(io::IO, table::Table)
    print(io, "<table>\n")
    header = any(r -> r isa TableHrule, table.rows)
    print(io, if header "<thead>\n" else "<tbody>\n" end)
    for row in table.rows
        if row isa TableHrule
            if header
                header = false
                print(io, "</thead>\n<tbody>\n")
            end
        else
            html(io, row, header)
            print(io, '\n')
        end
    end
    print(io, "</tbody>\n</table>")
end

# ---------------------
# Elements
# ---------------------

html(::IO, ::BabelCall) = nothing

html(::IO, ::CommentBlock) = nothing

function html(io::IO, block::ExampleBlock)
    print(io,
          html_tagwrap(join(block.contents, '\n'),
                       "pre", true, "class" => "example"))
end

function html(io::IO, block::SourceBlock)
    print(io,
          html_tagwrap(join(block.contents, '\n'),
                       "pre", true, "class" => "src"))
end

# Block
# Clock
# Planning
# DiarySexp

html(::IO, ::Comment) = nothing

function html(io::IO, fw::FixedWidth)
    print(io,
          html_tagwrap(join(html_escape.(fw.contents), '\n'),
                       "pre", "class" => "example"))
end

html(io::IO, ::HorizontalRule) = print(io, "<hr>")

# Keyword

html(::IO, ::Keyword) = nothing

# LaTeX Environment
# Node Property

function html(io::IO, par::Paragraph)
    print(io, "<p>")
    for obj in par.contents
        html(io, obj)
    end
    print(io, "</p>")
end

function html(io::IO, row::TableRow, header::Bool=false)
    open, close = html_tagpair("tr")
    print(io, open)
    foreach(c -> html(io, c, header), row.cells)
    print(io, close)
end

# ---------------------
# Objects
# ---------------------

html(io::IO, entity::Entity) = print(io, Entities[entity.name].html)

# LaTeX Fragment

html(io::IO, snippet::ExportSnippet) =
    if snippet.backend == "html" print(io, snippet.snippet) end

function html(io::IO, fn::FootnoteReference)
    print(io, "<a href=\"#fn_", html_escape(fn.label), "\">",
        "<sup>[", html_escape(fn.label), "]</sup></a>")
end

function html(io::IO, keycite::CitationReference)
    foreach(p -> html(io, p), keycite.prefix)
    print(io, html_tagwrap(keycite.key, "span", true, "class" => "citekey"))
    foreach(s -> html(io, s), keycite.suffix)
end

function html(io::IO, cite::Citation)
    print(io, "<span class=\"cite\">")
    foreach(p -> html(io, p), cite.globalprefix)
    for keycite in cite.citerefs
        html(io, keycite)
        keycite === last(cite.citerefs) || print(io, ", ")
    end
    foreach(s -> html(io, s), cite.globalsuffix)
    print(io, "</span>")
end

html(::IO, ::InlineBabelCall) = nothing

html(io::IO, src::InlineSourceBlock) =
    print(io, html_tagwrap(src.body, "code", true))

html(io::IO, ::LineBreak) = print(io, "<br>")

function html(io::IO, link::RadioLink)
    print(io, html_tagwrap(sprint(html, link.radio), "a",
                           "href" => "radio_" * string(hash(link.radio), base=62)))
end

function html(io::IO, path::LinkPath)
    if path.protocol in keys(link_uri_schemes)
        pathuri = link_uri_schemes[path.protocol](path.path)
        print(io, pathuri)
    end
end

function html(io::IO, link::Union{PlainLink, AngleLink})
    print(io, html_tagwrap(string(link.path), "a", true,
                           "href" => sprint(html, link.path)))
end

function html(io::IO, link::RegularLink)
    print(io, "<a href=\"", sprint(html, link.path),"\">")
    if isnothing(link.description) || length(link.description) == 0
        print(io, html_escape(string(link.path)))
    else
        foreach(o -> html(io, o), link.description)
    end
    print(io, "</a>")
end

function html(io::IO, o::OrgDoc, mac::Macro)
    expanded = macroexpand(o, mac)
    if isnothing(expanded)
        print(io, "{{{", html_escape(mac.name),
              '(', join(html_escape.(mac.arguments), ","), ")}}}")
    else
        foreach(o -> html(io, o),
                parseorg(expanded, org_object_matchers, org_object_fallbacks))
    end
end

function html(io::IO, target::RadioTarget)
    print(io, "<span id=\"radio_", string(hash(target), base=62), ">")
    foreach(o -> html(io, o), target.contents)
    print(io, "</a>")
end

html(io::IO, target::Target) =
    print(io, html_tagwrap("", "a",
                           "href" => '#' * string(hash(target.target), base=62)))

html(io::IO, statscookie::StatisticsCookiePercent) =
    print(io, '[', statscookie.percentage, "%]")
html(io::IO, statscookie::StatisticsCookieFraction) =
    print(io, '[', if !isnothing(statscookie.complete) string(statscookie.complete) else "" end,
          '/', if !isnothing(statscookie.total) string(statscookie.total) else "" end, ']')

html(io::IO, script::Superscript) =
    print(io, html_escape(string(script.char)), html_tagwrap(script.script, "sup", true))
html(io::IO, script::Subscript) =
    print(io, html_escape(string(script.char)), html_tagwrap(script.script, "sub", true))

function html(io::IO, cell::TableCell, header::Bool=false)
    open, close = html_tagpair(if header "th" else "td" end)
    print(io, open)
    foreach(o -> html(io, o), cell.contents)
    print(io, close)
end

function html(io::IO, tsrod::TimestampRepeaterOrDelay)
    timeunits = Dict('h' => "hour",
                     'd' => "day",
                     'w' => "week",
                     'm' => "month",
                     'y' => "year")
    if tsrod.type in (:cumulative, :catchup, :restart)
        print(io, "every ", tsrod.value, ' ', timeunits[tsrod.unit],
              if tsrod.value == 1 "" else 's' end, " thereafter")
    else
        print(io, "warning ", tsrod.value, ' ', timeunits[tsrod.unit],
              if tsrod.value == 1 "" else 's' end, " before")
    end
end

function html(io::IO, ts::TimestampInstant)
    if isnothing(ts.time)
        print(io,
              html_tagwrap(Dates.format(ts.date, dateformat"e d u Y"),
                           "time", "datetime" => Dates.format(ts.date, ISODateFormat)))
    else
        print(io,
              html_tagwrap(Dates.format(ts.date, dateformat"H:M e d u Y"),
                           "time", "datetime" => Dates.format(DateTime(ts.date, ts.time),
                                                              ISODateTimeFormat)))
    end
    if !isnothing(ts.repeater)
        print(io, " and ")
        html(io, ts.repeater)
    end
    if !isnothing(ts.warning)
        printstyled(io, ", ")
        html(io, ts.warning)
    end
end

function html(io::IO, tsr::TimestampRange)
    html(io, tsr.start)
    print(io, " &ndash; ")
    html(io, tsr.stop)
end

const html_markup_codes =
    Dict(:bold => html_tagpair("b"),
         :italic => html_tagpair("em"),
         :strikethrough => html_tagpair("s"),
         :underline => html_tagpair("span", "style" => "text-decoration: underline"),
         :verbatim => html_tagpair("kbd"),
         :code => html_tagpair("code"))

function html(io::IO, markup::TextMarkup)
    tagopen, tagclose = html_markup_codes[markup.formatting]
    print(io, tagopen)
    if markup.contents isa AbstractString
        print(io, html_escape(markup.contents))
    else
        html.(Ref(io), markup.contents)
    end
    print(io, tagclose)
end

function html(io::IO, text::TextPlain)
    tsub = replace(replace(replace(replace(html_escape(text.text),
                                           "..." => "&hellip;"),
                                   r"---([^-])" => s"&mdash;\1"),
                           r"--([^-])" => s"&mdash;\1"),
                   r"\\-" => "&shy;")
    print(io, tsub)
end

# ---------------------
# Catchall
# ---------------------

function html(io::IO, component::OrgComponent)
    @warn "No method for converting $(typeof(component)) to a term representation currently exists"
    print(io, html_escape(sprint(org, component)), '\n')
end
