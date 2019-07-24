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

export parser!, OrgDocument, Headline, Paragraph

import Base: size, getindex, setindex!, IndexStyle, iterate, length,
    firstindex, lastindex, push!

abstract type AbstractOrg end

abstract type ContainerOrg <: AbstractOrg end
abstract type InlineOrg <: AbstractOrg end

# Forward array interface methods
size(a::ContainerOrg) = size(a.content)
getindex(a::ContainerOrg, i::Int) = getindex(a.content, i)
setindex!(a::ContainerOrg, i::Int) = setindex!(a.content, i)
IndexStyle(a::ContainerOrg) = IndexStyle(a.content)
length(a::ContainerOrg) = length(a.content)
iterate(a::ContainerOrg, args...) = iterate(a.content, args...)
firstindex(::ContainerOrg) = 1
lastindex(a::ContainerOrg) = length(a)
push!(a::ContainerOrg, items...) = push!(a.content, items...)

struct OrgDocument <: ContainerOrg
    content::Vector{ContainerOrg}
end#struct
OrgDocument() = OrgDocument(ContainerOrg[])

level(::AbstractOrg) = typemax(Int)

find_nesting(org::AbstractOrg, l::Integer=typemax(Int)) =
    # Case of isempty(org) && level(org) >= l not possible in this recursion
    isempty(org) || level(last(org)) >= l ? org : find_nesting(last(org), l)

# ** Parsers

"""
    parser!(line::AbstractString, org::OrgDocument, T::Type{AbstractOrg})

Attempt to parse next line from io as T.

If successful, it returns an instance of `T` that is `push!`ed to
`org`. If unsuccesful, returns `nothing`.
"""
function parser! end

# *** Headline

struct Headline <: ContainerOrg
    title::String
    level::Int8
    tags::Vector{String}
    content::Vector{ContainerOrg}
end#struct

level(hl::Headline) = hl.level

function parser!(line::AbstractString, org::OrgDocument, ::Type{Headline})
    # Determine headline level and whether validly formatted
    level = 0
    for c in line
        c != '*' && break
        level += 1
    end#for
    if iszero(level) || level == length(line) || @inbounds line[level + 1] != ' '
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
    num_tag_chars = mapreduce(length, +, tags; init=0) + length(tags)
    # One more colon than number of tags
    num_tag_chars != 0 && (num_tag_chars += 1)

    title = strip(line[level + 1:length(line) - num_tag_chars])

    hl = Headline(title, level, tags, ContainerOrg[])
    push!(find_nesting(org, level), hl)
    hl
end#function

# *** Paragraph

# Paragraph is basically the fallback parser if nothing else fits. In
# the future, we will have inline parsers to look for things like
# *bold*, /italics/, _underline_, [[links][https://julialang.org]], but for right
# now, we just hold them as plain text.

mutable struct Paragraph <: ContainerOrg
    content::Vector{Union{InlineOrg,String}}
    finished::Bool
end#struct
Paragraph() = Paragraph(Vector{Union{InlineOrg,String}}(), false)

"Finds and returns the last paragraph in document if its last `ContainerOrg`."
last_paragraph(org::ContainerOrg) =
    isempty(org) ? nothing : last_paragraph(last(org))
last_paragraph(org::Paragraph) = org

function parser!(line::AbstractString, org::OrgDocument, ::Type{Paragraph})
    paragraph = last_paragraph(org)
    if isempty(line) && paragraph === nothing
        # Don't change anything and proceed to next line
        paragraph = Paragraph()
    elseif isempty(line)
        # Otherwise just mark paragraph as finished on empty line
        paragraph.finished = true
    elseif paragraph === nothing || paragraph.finished
        paragraph = Paragraph()
        push!(paragraph, line * '\n')
        push!(find_nesting(org), paragraph)
    else
        # TODO: should each line be stored separately in `Paragraph`?
        paragraph.content[end] = paragraph.content[end] * line * '\n'
    end#if
    paragraph
end#function

end # module
