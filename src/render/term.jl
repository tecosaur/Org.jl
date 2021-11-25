show(io::IO, ::MIME"text/plain", org::Org) = (term(io, org), nothing)

term(io::IO, org::Org) = term.(Ref(io), org.content)

# ---------------------
# Sections
# ---------------------

function term(io::IO, section::Section)
    term(io, section.heading)
    print(io, "\n")
    term.(Ref(io), section.content)
end

const heading_keyword_colors = Dict("TODO" => :green,
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
function term(io::IO, heading::Heading)
    printstyled(io, "\n", "*"^heading.level, " ", color=:blue)
    if !isnothing(heading.keyword)
        kcolor = if heading.keyword in keys(heading_keyword_colors)
            heading_keyword_colors[heading.keyword]
        else
            :green
        end
        printstyled(heading.keyword, " ", color=kcolor)
    end
    if !isnothing(heading.priority)
        printstyled("[#", heading.priority, "] ", color=:red)
    end
    printstyled(heading.title, color=:blue)
    if length(heading.tags) > 0
        printstyled(" :", join(heading.tags, ":"), ":", color=:light_black)
    end
end

# ---------------------
# Greater Elements
# ---------------------

function term(io::IO, table::Table)
    org(io::IO, table, table_charset_boxdraw)
end

# ---------------------
# Elements
# ---------------------

function term(io::IO, keyword::Keyword)
    printstyled(io, "#+", keyword.key, ": ", color=:light_black)
    printstyled(io, keyword.value, "\n", color=:magenta)
end

function term(io::IO, paragraph::Paragraph)
    term.(Ref(io), paragraph.objects)
end

# ---------------------
# Objects
# ---------------------

function term(io::IO, ent::Entity)
    print(io, Entities[ent.name].utf8, ent.post)
end

function term(io::IO, latex::LaTeXFragment)
    if isnothing(latex.delimiters)
        printstyled(io, latex.contents, color=:magenta)
    else
        printstyled(io, latex.delimiters[1], latex.contents,
                    latex.delimiters[2], color=:magenta)
    end
end

# ExportSnippet

# FootnoteRef

# InlineBabelCall

# InlineSourceBlock

# LineBreak

function term(io::IO, ::LineBreak)
    print(io, "\n")
end

# Link

const link_uri_schemes =
    Dict("https" => p -> "https://$p",
         "file" => p -> "file://$(abspath(p))")
const link_protocol_prefixes =
    Dict(:coderef => p -> "($p)",
         :custom_id => p -> "#$p",
         :heading => p -> "*$p",
         :fuzzy => identity)
function term(io::IO, link::Link)
    pathstr = if link.path.protocol isa AbstractString
        link.path.protocol * ":" * link.path.path
    elseif link.path.protocol in keys(link_protocol_prefixes)
        link_protocol_prefixes[link.path.protocol](link.path.path)
    else
        "?:$(link.path.path)"
    end
    if link.path.protocol in keys(link_uri_schemes)
        pathuri = link_uri_schemes[link.path.protocol](link.path.path)
        if isnothing(link.description)
            print(io, "\e]8;;$pathuri\e\\\e[4;34m$pathstr\e[0;0m\e]8;;\e\\")
        else
            print(io, "\e]8;;$pathuri\e\\\e[4;34m$(link.description)\e[0;0m\e]8;;\e\\")
        end
    else
        print(io, "\e[9;34m", "[[$pathstr]",
              if isnothing(link.description) "" else
                  "[$(link.description)]" end,
              "]", "\e[0;0m")
    end
end

# Macro

function term(io::IO, mac::Macro)
    printstyled(io, "{{{", color=:light_black)
    printstyled(io, mac.name, "(", join(mac.arguments, ", "), ")",
                bold=true, color=:light_black)
    printstyled(io, "}}}", color=:light_black)
end

# RadioTarget

# Target

# StatisticsCookie

# Script

# Timestamp

# TextMarkup

const markup_term_codes = Dict(:bold => "\e[1m",
                               :italic => "\e[3m",
                               :strikethrough => "\e[9m",
                               :underline => "\e[4m",
                               :verbatim => "\e[32m", # green
                               :code => "\e[36m") # cyan
function term(io::IO, markup::TextMarkup, accumulatedmarkup="")
    print(io, markup.pre)
    if markup.type in keys(markup_term_codes)
        accumulatedmarkup *= markup_term_codes[markup.type]
    end
    if markup.contents isa AbstractString
        print(io, accumulatedmarkup, markup.contents, "\e[0;0m")
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
    print(io, accumulatedmarkup, text.text, "\e[0;0m")
end

# ---------------------
# Catchall
# ---------------------

function term(io::IO, todo::OrgComponent)
    print(io, todo)
end
