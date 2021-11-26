show(io::IO, ::MIME"text/plain", org::Org) = (term(io, org), nothing)

term(io::IO, org::Org) = term.(Ref(io), org.contents)
term(org::OrgComponent) = term(stdout, org)

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

function term(io::IO, heading::Heading)
    printstyled(io, "*"^heading.level, ' ', color=:blue)
    if !isnothing(heading.keyword)
        kcolor = if heading.keyword in keys(HeadingKeywordColors)
            HeadingKeywordColors[heading.keyword]
        else
            :green
        end
        printstyled(heading.keyword, ' ', color=kcolor)
    end
    if !isnothing(heading.priority)
        printstyled("[#", heading.priority, "] ", color=:red)
    end
    printstyled(heading.title, color=:blue)
    if length(heading.tags) > 0
        printstyled(" :", join(heading.tags, ":"), ":", color=:light_black)
    end
    if !isnothing(heading.section)
        print(io, "\n\n")
        term(io, heading.section)
    end
end

function term(io::IO, section::Section)
    for component in section.contents
        term(io, component)
        component == last(section.contents) || print(io, '\n')
    end
end

# ---------------------
# Greater Elements
# ---------------------

# Greater Block
# Drawer
# Dynamic Block
# Footnote Def
# Inline Task

function term(io::IO, list::List, depth=0)
    term.(Ref(io), list.items, list isa UnorderedList, depth)
end

function term(io::IO, item::Item, unordered::Bool=true, depth=0)
    print(io, ' '^2depth)
    if unordered
        printstyled(io, if depth % 2 == 0 '➤' else '•' end, ' ', color=:blue)
    else
        printstyled(io, item.bullet, ' ', color=:blue)
    end
    if !isnothing(item.contents)
        term.(Ref(io), item.contents)
    end
    print(io, '\n')
    if !isnothing(item.sublist)
        term(io, item.sublist, depth+1)
    end
end

# Property Drawer

function term(io::IO, table::Table)
    org(io::IO, table, table_charset_boxdraw)
end

# ---------------------
# Elements
# ---------------------

# Babel Call
# Comment Block
function term(io::IO, block::ExampleBlock)
    printblockcontent(io, "║ ", :light_black, block.contents, :cyan)
end
function printblockcontent(io, prefix::AbstractString, prefixcolor::Symbol, content::AbstractString, contentcolor::Symbol=:default)
    lines = replace.(split(content, '\n'), r"^,\*" => "*")
    printstyled(io, prefix, color=prefixcolor)
    printstyled(lines[1], color=contentcolor)
    for line in lines[2:end]
        printstyled(io, "\n", prefix, color=prefixcolor)
        printstyled(io, line, color=contentcolor)
    end
end
function term(io::IO, srcblock::SourceBlock)
    printstyled(io, "╭\n", color=:light_black)
    printblockcontent(io, "│ ", :light_black, srcblock.contents, :cyan)
    printstyled(io, "\n╰", color=:light_black)
end
# Verse Block
function term(io::IO, block::CustomBlock)
    printstyled(io, "#+begin_", block.name, '\n', color=:light_black)
    print(io, block.contents)
    printstyled(io, "\n#+end_", block.name, color=:light_black)
end
# DiarySexp
# Comment
# Fixed Width

function term(io::IO, ::HorizontalRule)
    printstyled(io, ' ', '─'^(displaysize(io)[2]-2), '\n', color=:light_black)
end

const DocumentInfoKeywords = ["title", "subtitle", "author"]

function term(io::IO, keyword::Keyword)
    if keyword.key in DocumentInfoKeywords
        printstyled(io, "#+", keyword.key, ": ", color=:light_black)
        printstyled(io, keyword.value, color=:magenta)
    else
        printstyled(io, "#+", keyword.key, ": ", keyword.value, color=:light_black)
    end
end

# LaTeX Environment
# Node Property

function term(io::IO, paragraph::Paragraph)
    term.(Ref(io), paragraph.objects)
end

# Table Row
# Empty Line

function term(io::IO, ::EmptyLine) end

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

function term(io::IO, src::InlineSourceBlock)
    printstyled(io, src.body, color=:cyan)
end

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
    print(io, todo, '\n')
end
