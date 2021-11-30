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

function html(io::IO, o::Org)
    for component in o.contents
        html(io, component)
        print(io, '\n')
    end
end

html(o::Union{Org, OrgComponent}) = html(stdout, o)

function html(_::IO, component::C) where { C <: OrgComponent}
    @warn "No method for converting $C to a html representation currently exists"
end

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
        print(io, '\n')
    end
end

# ---------------------
# Greater Elements
# ---------------------

# Greater Block
# Drawer
# Dynamic Block
# FootnoteDef
# InlineTask

function html(io::IO, item::Item)
    open, close = html_tagpair("li")
    print(io, open)
    # TODO support counterset
    # TODO support checkbox better
    if !isnothing(item.checkbox)
        print(io, " [", item.checkbox, "] ")
    end
    if !isnothing(item.tag)
        print(io, html_escape(item.tag), " :: ")
    end
    if !isnothing(item.contents)
        html.(Ref(io), item.contents)
    end
    if !isnothing(item.sublist)
        html(io, item.sublist)
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

# PropertyDrawer
# Table

# ---------------------
# Elements
# ---------------------

# Babel Call
# Block
# Clock
# Planning
# DiarySexp
# Comment
# Fixed Width
# Horizontal Rule
# Keyword
# LaTeX Environment
# Node Property

function html(io::IO, par::Paragraph)
    print(io, "<p>")
    for obj in par.contents
        html(io, obj)
    end
    print(io, "</p>")
end

# Table Row

html(io::IO, ::EmptyLine) = print(io, "<br>")

# ---------------------
# Objects
# ---------------------

html(io::IO, entity::Entity) = print(io, Entities[entity.name].html, entity.post)

# LaTeX Fragment

html(io::IO, snippet::ExportSnippet) =
    if snippet.backend == "html" print(io, snippet.snippet) end

# Footnote Ref
# Inline Babel Call
# Inline Source Block
# Line Break
# Link
# Macro
# Radio Target

html(io::IO, target::Target) =
    print(io, html_tagwrap("", "a", "href" => string('#', hash(target.target))))

html(io::IO, statscookie::StatisticsCookiePercent) =
    print(io, '[', statscookie.percentage, "%]")
html(io::IO, statscookie::StatisticsCookieFraction) =
    print(io, '[', if !isnothing(statscookie.complete) string(statscookie.complete) else "" end,
          '/', if !isnothing(statscookie.total) string(statscookie.total) else "" end, ']')

html(io::IO, script::Superscript) =
    print(io, html_escape(script.char), html_tagwrap(script.script, "sup", true))
html(io::IO, script::Subscript) =
    print(io, html_escape(script.char), html_tagwrap(script.script, "sub", true))

# Table Cell

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

const html_markup_codes =
    Dict(:bold => html_tagpair("b"),
         :italic => html_tagpair("em"),
         :strikethrough => html_tagpair("s"),
         :underline => html_tagpair("span", "style" => "text-decoration: underline"),
         :verbatim => html_tagpair("kbd"),
         :code => html_tagpair("code"))

function html(io::IO, markup::TextMarkup)
    tagopen, tagclose = html_markup_codes[markup.type]
    print(io, html_escape(markup.pre), tagopen)
    if markup.contents isa AbstractString
        print(io, html_escape(markup.contents))
    else
        html.(Ref(io), markup.contents)
    end
    print(io, tagclose, html_escape(markup.post))
end


function html(io::IO, text::TextPlain)
    tsub = replace(replace(replace(replace(html_escape(text.text),
                                           "..." => "&hellip;"),
                                   r"---([^-])" => s"&mdash;\1"),
                           r"--([^-])" => s"&mdash;\1"),
                   r"\\-" => "&shy;")
    print(io, tsub)
end
