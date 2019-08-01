# This file is part of Org.jl.
#
# Org.jl is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Org.jl is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.

# * Org.jl

module Org

export parser!,
       parse_org,
       level,
       nocontext,
       NoContext,
       Document,
       Headline,
       Paragraph

import Base: size,
             getindex,
             setindex!,
             IndexStyle,
             iterate,
             length,
             firstindex,
             lastindex,
             push!

abstract type AbstractOrg end

abstract type Container <: AbstractOrg end
abstract type Inline <: AbstractOrg end
abstract type Interruptible <: Container end

# Forward array interface methods
size(a::Container) = size(a.content)
getindex(a::Container, i::Int) = getindex(a.content, i)
setindex!(a::Container, i::Int) = setindex!(a.content, i)
IndexStyle(a::Container) = IndexStyle(a.content)
length(a::Container) = length(a.content)
iterate(a::Container, args...) = iterate(a.content, args...)
firstindex(::Container) = 1
lastindex(a::Container) = length(a)
push!(a::Container, items...) = push!(a.content, items...)

"""
Represents an org-mode document.
"""
struct Document <: Container
    content::Vector{Container}
end#struct
Document() = Document(Container[])

"""
    level(org)

Return the folding level of a given org element.

For purpose of this function, "level" is `typemax(Int)` for all elements that
cannot be folded. Headlines will have a "level" equal to the number of leading
asterisks.
"""
level(::AbstractOrg) = typemax(Int)

find_nesting(org::AbstractOrg, l::Integer = typemax(Int)) =
    isempty(org) || level(last(org)) >= l ? org : find_nesting(last(org), l)

# ** Parsers

"""
    parser!(line, org_document, T::Type{ContainerOrg}, context::ContainerOrg)

Attempt to parse line as T.

If successful, it returns an instance of `T` that is `push!`ed to
`org`. This instance is used as the context to the next call of `parser!`. If
unsuccessful, returns `nothing`. `nocontext` can be used if there is no ongoing
org element.
"""
function parser!(::AbstractString, ::Document, ::Type{<:Container}, ::Container)
    # If a ContainerOrg doesn't recognize a context fallback to not parsing it.
    # This means we can try to parse with the same set of types even when in a
    # context that requires closure before another container is added.
    nothing
end

"""
    NoContext()

Represent the state of not needing prior context to parse next line.

`nocontext` is an instance of `NoContext`.
"""
struct NoContext <: Interruptible end
const nocontext = NoContext()

# *** Paragraph

# Paragraph is basically the fallback parser if nothing else fits. In
# the future, we will have inline parsers to look for things like
# *bold*, /italics/, _underline_, [[links][https://julialang.org]], but for right
# now, we just hold them as plain text.

"""
    Paragraph()

Represent a paragraph.

A paragraph is any element delimited either by blank lines or the
start and end of other blocks that is not parsed as another kind of
element.
"""
mutable struct Paragraph <: Interruptible
    content::Vector{Union{Inline,String}}
end#struct
Paragraph() = Paragraph(Vector{Union{Inline,String}}())

function parser!(
    line::AbstractString,
    org::Document,
    ::Type{Paragraph},
    ::Interruptible
)
    isempty(line) && return nocontext

    paragraph = Paragraph()
    push!(paragraph, line * '\n')
    push!(find_nesting(org), paragraph)
    paragraph
end#function

function parser!(
    line::AbstractString,
    ::Document,
    ::Type{Paragraph},
    p::Paragraph
)
    if isempty(line)
        nocontext
    else
        push!(p, line * '\n')
        p
    end#if
end#function

# *** Headline

"""
    Headline(title, level, tags, content)

An org headline is a container for other blocks.

The headline showed below will be parsed as a title of "Foo Bar" with
tags "barrr", "foo", "bar", and "foo". It has a `level` of 2 and its
content is a paragraph containing the text "Hello world. I love you."

```org
** Foo Bar                                                :barrr:foo:bar:foo:

Hello world. I love you.
```
"""
struct Headline <: Interruptible
    title::String
    level::Int8
    tags::Vector{String}
    content::Vector{Container}
end#struct

level(hl::Headline) = hl.level

function parser!(
    line::AbstractString,
    org::Document,
    ::Type{Headline},
    ::Interruptible
)
    # Determine headline level and whether validly formatted
    level = 0
    for c in line
        c != '*' && break
        level += 1
    end#for
    if iszero(level) || level == length(line) || @inbounds line[level+1] != ' '
        return nothing
    end#if

    # Determine whether tags exist and add all found tags
    tags = String[]
    if endswith(line, ':')
        # First string is empty for ':' that headline ends with
        for tag in reverse(split(line, ':'))[2:end]
            if length(tag) != 0 && all(isletter, tag)
                push!(tags, tag)
            else
                break
            end#if
        end#for
        reverse!(tags)
    end#if
    num_tag_chars = mapreduce(length, +, tags; init = 0) + length(tags)
    # One more colon than number of tags
    num_tag_chars != 0 && (num_tag_chars += 1)

    title = strip(line[level+1:length(line)-num_tag_chars])

    hl = Headline(title, level, tags, Container[])
    push!(find_nesting(org, level), hl)
    hl
end#function

# ** Parse Document

const container_types = (Headline, Paragraph)

"""
    parse_org(doc::IO[, parser_targets])::Document

Parse a stream.
"""
function parse_org(doc::IO, parser_targets = container_types)::Document
    org = Document()
    context = nocontext
    for line in eachline(doc)
        for target in parser_targets
            x = parser!(line, org, target, context)
            if x !== nothing
                context = x
                break
            end#if
        end#for
    end#for
    org
end#function

"""
    parse_org(doc::AbstractString[, parser_targets])::Document

Parse a string that contains org.
"""
parse_org(doc::AbstractString, args...) = parse_org(IOBuffer(doc), args...)

Document(org::Union{IO,AbstractString}) = parse_org(org)

# ** End module

end # module
