# SPDX-FileCopyrightText: © 2025 TEC <contact@tecosaur.net>
# SPDX-License-Identifier: MPL-2.0

struct Token
    kind::Kind
    start::UInt32
    stop::UInt32
end

struct Lexer{I <: DenseVector{UInt8}}
    input::I
end

Lexer(string::AbstractString) = Lexer(codeunits(string))

struct LexerState
    position::UInt32
    ctx::Kind
    restriction::Kind
    lastelement::Kind
end

LexerState() = LexerState(1, K"", restrictions(K""), K"")

Base.iterate(lex::Lexer) = iterate(lex, LexerState())
Base.eltype(::Type{<:Lexer}) = Token
Base.IteratorSize(::Type{<:Lexer}) = Base.SizeUnknown()

function Base.iterate(lex::Lexer, state::LexerState)
    state.position <= length(lex.input) || return
    (; position, ctx, restriction, lastelement) = state
    local token
    while position <= length(lex.input)
        token, position = @inline lexnext(state, lex.input, position)
        if token.kind in K"elements"
            lastelement = token.kind
        end
        if token.kind == K"plaintext"
        elseif token.kind == K"heading"
            ctx = K""
            restriction = restrictions(ctx)
            break
        elseif token.kind ∈ K"block"
            break
        elseif isbegin(token.kind) || isend(token.kind)
            ctx = ctx ⊻ plain(token.kind)
            restriction = restrictions(ctx)
            break
        else
            break
        end
    end
    token.kind ∈ (K"", K"plaintext") && return
    token, LexerState(position, ctx, restriction, lastelement)
end


# Lexing entrypoint

"""
    NONE_TOKEN

A token that represents the absence of a token.

This is intended for use stand-in for `nothing` without
introducing type instability.
"""
const NONE_TOKEN = Token(K"", 0, 0), UInt32(0)

function lexnext(state::LexerState, bytes::DenseVector{UInt8}, start::UInt32)::Tuple{Token, UInt32}
    linestart, newlines = @inline skipnewlines(bytes, start)
    skipws = skipspaces(bytes, linestart)
    pos = skipws.stop
    chr = bytes[pos]
    next = if newlines > 0 && K"clock" ∈ state.ctx
        Token(K">clock", start - 0x01, start - 0x01), start
    elseif newlines > 2 && K"footnote_definition" ∈ state.ctx
        Token(K">footnote_definition", start - 0x1, start - 0x1), start
    elseif newlines != 0
        if K"table" ∈ state.ctx
            if chr == UInt8('|')
                if ischarat(bytes, pos + 0x1, '-')
                    lend = lineend(bytes, pos)
                    Token(K"table_row[1]", pos, lend - 0x1), lend
                else
                    Token(K"<table_row", pos, pos), pos + 0x1
                end
            else
                Token(K">table", start - 0x1, start - 0x1), start
            end
        elseif K"clock" ∈ state.ctx
            Token(K">clock", start - 0x1, start - 0x1), start
        elseif chr == UInt8('*') && pos == linestart && ischarat(bytes, pos + countsame(bytes, pos, '*'), ' ')
            lex_heading(state, bytes, pos)
        elseif chr == UInt8(':')
            lex_drawer(state, bytes, pos)
        elseif chr == UInt8('[') && pos == linestart
            fndef = lex_footnotedef(state, bytes, pos)
            if fndef != NONE_TOKEN && K"footnote_definition" ∈ state.ctx
                Token(K">footnote_definition", start - 0x1, start - 0x1), start
            else
                fndef
            end
        elseif chr == UInt8('|') && K"table" ∈ state.restriction
            Token(K"<table", pos, pos), pos
        elseif chr == UInt8('#') && ischarat(bytes, pos + 0x1, '+')
            lex_hashplus(state, bytes, pos)
        elseif chr == UInt8('c') && hasprefix(bytes, pos + 0x1, "lock:")
            lex_clock(state, bytes, pos)
        elseif chr == UInt8('%') && ischarat(bytes, pos + 0x1, '%')
            lex_diarysexp(state, bytes, pos)
        elseif chr == UInt8('#') && (length(bytes) > pos && iswhitespace(bytes, pos + 0x1) || islineend(bytes, pos + 0x1))
            lex_comment(state, bytes, pos)
        elseif K"heading" ∈ state.lastelement
            lex_planning(state, bytes, pos)
        else
            if K"item" ∈ state.restriction
                lex_item(state, bytes, pos, skipws.width)
            else
                NONE_TOKEN
            end
        end
    else # No newlines
        if K"table" ∈ state.ctx && islineend(bytes, pos + 0x1)
            if K"table_cell" ∈ state.ctx
                Token(K">table_cell", pos, pos), pos
            elseif K"table_row" ∈ state.ctx
                Token(K">table_row", pos, pos), pos + 0x1
            else
                NONE_TOKEN
            end
        elseif K"table_row" ∈ state.ctx
            if K"table_cell" ∈ state.ctx
                cellend = min(length(bytes), nextchar(bytes, pos, ('|', '\n', '\r')))
                cellend -= (bytes[cellend] ∈ (UInt8('\n'), UInt8('\r'))) % UInt32
                Token(K">table_cell", cellend, cellend), cellend
            else
                if bytes[pos] == UInt8('|')
                    pos += 0x1
                end
                Token(K"<table_cell", pos, pos), pos
            end
        else
            NONE_TOKEN
        end
    end
    if next != NONE_TOKEN
        next
    else
        npos = @inline skipplain(bytes, pos)
        if pos == npos && pos < length(bytes)
            npos = @inline skipplain(bytes, pos + 0x1)
        end
        Token(K"plaintext", linestart, npos - 0x1), npos
    end
end


# Greater element lexing

function lex_heading(::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    depth = countsame(bytes, pos, '*')
    Token(settag(K"heading", depth % UInt8), pos, lineend(bytes, pos) - 1),
    pos + depth
end

function lex_drawer(state::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    kind, drawend = if state.lastelement ∈ K"heading|planning" && hasprefix(bytes, pos, ":properties:")
        K"<property_drawer", pos + ncodeunits(":properties:") % UInt32
    elseif hasprefix(bytes, pos, ":end:")
        if K"property_drawer" ∈ state.ctx
            K">property_drawer"
        elseif K"drawer" ∈ state.ctx
            K">drawer"
        else
            return NONE_TOKEN
        end, pos + ncodeunits(":end:") % UInt32
    elseif K"property_drawer" ∈ state.ctx
        nameend = nextchar(bytes, pos + 0x1, (' ', '\t'))
        bytes[nameend - 1] == UInt8(':') || return NONE_TOKEN
        K"node_property", lineend(bytes, nameend)
    elseif K"drawer" ∈ state.restriction
        nameend = nextchar(bytes, pos + 0x1, ':')
        nameend == skipwords(bytes, pos + 0x1, ('-', '_')) || return NONE_TOKEN
        K"<drawer", nameend + 0x1
    else
        return NONE_TOKEN
    end
    drawend = skipspaces(bytes, drawend).stop
    islineend(bytes, drawend) || return NONE_TOKEN
    Token(kind, pos, drawend - 0x1), drawend
end

function lex_footnotedef(::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    hasprefix(bytes, pos, "[fn:") || return NONE_TOKEN
    fnend = skipwords(bytes, pos + ncodeunits("[fn:") % UInt32, ('-', '_'))
    bytes[fnend] == UInt8(']') || return NONE_TOKEN
    Token(K"<footnote_definition", pos, fnend), fnend + 0x1
end

function lex_item(::LexerState, bytes::DenseVector{UInt8}, start::UInt32, column::Integer)
    function read_bullet(bytes::DenseVector{UInt8}, pos::Integer)
        pos = if bytes[pos] ∈ (UInt8('-'), UInt8('+'), UInt8('*'))
            pos + 0x1
        else
            bulletend = nextchar(bytes, pos, ('.', ')', '\n', '\r'))
            if bulletend >= length(bytes) ||
                bytes[bulletend] ∈ (UInt8('\n'), UInt8('\r')) ||
                nextchar(bytes, pos, (' ', '\n', '\r')) < bulletend
                return zero(pos)
            end
            bulletend == skipcharsets(bytes, pos, '0':'9') ||
                bulletend == skipcharsets(bytes, pos, 'a':'z', 'A':'Z') ||
                return zero(pos)
            bulletend + 0x1
        end
        bytes[pos] ∈ (UInt8(' '), UInt8('\t')) || return zero(pos)
        skipspaces(bytes, pos).stop
    end
    pos = read_bullet(bytes, start)
    pos != 0 || return NONE_TOKEN
    contentend = lineend(bytes, pos)
    while contentend < length(bytes)
        pos, newlines = skipnewlines(bytes, contentend)
        newlines > 2 && break
        ws = skipspaces(bytes, pos)
        if ws.width <= column
            break
        elseif last(read_bullet(bytes, ws.stop)) != 0
            break
        else
            contentend = lineend(bytes, pos)
        end
    end
    Token(settag(K"item", UInt8(column + one(column))), start, contentend), contentend + 0x1
end

function lex_hashplus(state::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    blk = lex_block(state, bytes, pos)
    blk != NONE_TOKEN && return blk
    blk = lex_dynamicblock(state, bytes, pos)
    blk != NONE_TOKEN && return blk
    if K"keyword" in state.restriction
        blk = lex_keyword(state, bytes, pos)
        blk != NONE_TOKEN && return blk
    end
    NONE_TOKEN
end

function lex_block((; ctx)::LexerState, bytes::DenseVector{UInt8}, start::UInt32)
    mode, pos = if hasprefix(bytes, start, "#+begin_")
        K"<", start + ncodeunits("#+begin_") % UInt32
    elseif hasprefix(bytes, start, "#+end_")
        K">", start + ncodeunits("#+end_") % UInt32
    else
        return NONE_TOKEN
    end
    lend = lineend(bytes, pos)
    nameend = untilwhitespace(bytes, pos)
    containswhitespace(bytes, pos, nameend) && return NONE_TOKEN
    for (name, kind) in (("comment", K"comment_block"),
                         ("example", K"example_block"),
                         ("export",  K"export_block"),
                         ("verse",   K"verse_block"),
                         ("src",     K"source_block"))
        if nameend - pos + 1 == ncodeunits(name) && hasprefix(bytes, pos, name)
            return if mode == K"<" && isempty(K"lesser_blocks" & ctx)
                heurstart = lend + (bytes[lend] == UInt8('\r')) % UInt32
                if kind in K"comment_block|example_block|export_block|source_block"
                    while heurstart < length(bytes) && !ischarat(bytes, heurstart + 0x1, '*')
                        heurnext = skipspaces(bytes, heurstart + 0x1).stop
                        if hasprefix(bytes, heurnext, "#+end_") &&
                            hasprefix(bytes, heurnext + ncodeunits("#+end_"), name)
                            break
                        else
                            heurstart = lineend(bytes, heurnext)
                            if bytes[heurstart] == UInt8('\r')
                                heurstart += 0x1
                            end
                        end
                    end
                end
                Token(kind | mode, start, lend - 1), lend
            elseif mode == K">" && kind ∈ ctx
                Token(kind | mode, start, lend - 1), lend
            else
                NONE_TOKEN
            end
        end
    end
    tag = word2tag(bytes, pos, nameend - 1)
    Token(settag(K"block" | mode, tag), start, lend - 1), lend
end

function lex_dynamicblock(state::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    mode, prefixlen = if hasprefix(bytes, pos, "#+begin:") && K"dynamic_block" ∈ state.restriction
        K"<", ncodeunits("#+begin:")
    elseif hasprefix(bytes, pos, "#+end:") && K"dynamic_block" ∈ state.ctx
        K">", ncodeunits("#+end:")
    else
        return NONE_TOKEN
    end
    ws = skipspaces(bytes, pos + prefixlen)
    if mode == ">" && !islineend(bytes, ws.stop)
        return NONE_TOKEN
    end
    nameend = untilwhitespace(bytes, pos + prefixlen)
    containswhitespace(bytes, pos, nameend) && return NONE_TOKEN
    lend = lineend(bytes, pos)
    tag = word2tag(bytes, pos + prefixlen, nameend - 1)
    Token(settag(K"dynamic_block" | mode, tag), pos, lend - 1), lend
end

function lex_keyword(::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    if !hasprefix(bytes, pos, "#+")
        return NONE_TOKEN
    end
    nameend = nextchar(bytes, pos, ':')
    nameend > length(bytes) && return NONE_TOKEN
    containswhitespace(bytes, pos, nameend) && return NONE_TOKEN
    lend = lineend(bytes, pos)
    tag = word2tag(bytes, pos + 2, nameend - 1)
    Token(settag(K"keyword", tag), pos, lend - 1), lend
end


# Lesser element lexing

function lex_clock(::LexerState, bytes::DenseVector{UInt8}, start::UInt32)
    hasprefix(bytes, start, "clock:") || return NONE_TOKEN
    pos = start + ncodeunits("clock:") % UInt32
    pos = skipspaces(bytes, pos).stop
    hastimestamp = if bytes[pos] == UInt8('[')
        pos = nextchar(bytes, pos + 0x1, (']', '\n'))
        ischarat(bytes, pos, ']') && (pos += 0x1)
        if hasprefix(bytes, pos, "--[")
            pos = nextchar(bytes, pos + 0x4, (']', '\n'))
            ischarat(bytes, pos, ']') && (pos += 0x1)
        end
        pos = skipspaces(bytes, pos).stop
        true
    else
        false
    end
    hasduration = if hasprefix(bytes, pos, "=>")
        pos = skipspaces(bytes, pos + ncodeunits("=>") % UInt32).stop
        pos = skipcharsets(bytes, pos, '0':'9', ':')
        pos = skipspaces(bytes, pos).stop
        true
    else
        false
    end
    if (hastimestamp || hasduration) && islineend(bytes, pos)
        Token(K"<clock", start, start), start + ncodeunits("clock:") % UInt32
    else
        NONE_TOKEN
    end
end

function lex_diarysexp(::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    hasprefix(bytes, pos, "%%") || return NONE_TOKEN
    lend = lineend(bytes, pos)
    sexpend = skipbalanced(bytes, pos + 0x2, '(' => ')', quotes = ('"',), escapechar = '\\', limit = lend - 0x1)
    sexpend != 0 || return NONE_TOKEN
    if skipspaces(bytes, sexpend).stop == lend
        Token(K"diarysexp", pos, sexpend), lend
    else
        NONE_TOKEN
    end
end

function lex_planning(state::LexerState, bytes::DenseVector{UInt8}, start::UInt32)
    lend = lineend(bytes, start)
    pos = start
    sheduled, deadline, closed = false, false, false
    while skipspaces(bytes, pos).stop < lend
        pos = skipspaces(bytes, pos).stop
        if hasprefix(bytes, pos, "scheduled:")
            sheduled = true
            pos += ncodeunits("scheduled:") % UInt32
        elseif hasprefix(bytes, pos, "deadline:")
            deadline = true
            pos += ncodeunits("deadline:") % UInt32
        elseif hasprefix(bytes, pos, "closed:")
            closed = true
            pos += ncodeunits("closed:") % UInt32
        else
            return NONE_TOKEN
        end
        pos = skipspaces(bytes, pos).stop
        tsbrk, tsket = if ischarat(bytes, pos, '[')
            pos = nextchar(bytes, pos + 0x1, ']', limit = lend) + 0x1
            '[', ']'
        elseif ischarat(bytes, pos, '<')
            pos = nextchar(bytes, pos + 0x1, '>', limit = lend) + 0x1
            '<', '>'
        else
            return NONE_TOKEN
        end
        if hasprefix(bytes, pos, "--") && ischarat(bytes, pos + 0x2, tsbrk)
            pos = nextchar(bytes, pos + 0x3, tsket, limit = lend) + 0x1
        end
    end
    kwtag = 0x00
    for (flag, bit) in ((sheduled, 0x01),
                        (deadline, 0x02),
                        (closed, 0x04))
        flag && (kwtag |= bit)
    end
    if skipspaces(bytes, pos).stop == lend
        Token(settag(K"planning", kwtag), start, pos), lend
    else
        NONE_TOKEN
    end
end

function lex_comment(::LexerState, bytes::DenseVector{UInt8}, start::UInt32)
    pos, nextpos = start, start
    while pos <= length(bytes)
        nextpos = skipspaces(bytes, nextpos).stop
        ischarat(bytes, nextpos, '#') &&
            (islineend(bytes, nextpos + 0x1) ||
             nextpos < length(bytes) && iswhitespace(bytes, nextpos + 0x1)) ||
            break
        pos = lineend(bytes, nextpos) - 0x1
        nextpos = pos + 0x2
    end
    Token(K"comment", start, pos), nextpos
end

# TODO: Fixed width

# TODO: Horizontal rules

# TODO: LaTeX environments

# TODO: Paragraphs


# Object lexing

# TODO: Entities

# TODO: Export snippets

# TODO: Footnote references

# TODO: Citations

# TODO: Citation references

# TODO: Inline babel calls

# TODO: Line breaks

# TODO: Links: Radio links
# TODO: Links: Plain links
# TODO: Links: Angle links
# TODO: Links: Regular links

# TODO: Macros

# TODO: Targets
# TODO: Radio targets

# TODO: Statistics cookies

# TODO: Subscripts and superscripts

# TODO: Timestamps

# TODO: Text markup


# Utility functions

function skipspaces(bytes::DenseVector{UInt8}, pos::I; limit::I = length(bytes) % I) where {I <: Integer}
    wskipped = 0
    while pos <= limit
        if bytes[pos] == UInt8(' ')
            pos += 0x1
            wskipped += 1
        elseif bytes[pos] == UInt8('\t')
            pos += 0x1
            wskipped += 8
        elseif bytes[pos] == 0xe2 && limit >= pos + 0x2 &&
            bytes[pos + 1] == 0x80 && 0x80 <= bytes[pos + 2] <= 0x8c
            if bytes[pos + 2] < 0x8b
                wskipped += 1
            end
            pos += 0x3
        else
            break
        end
    end
    (width = wskipped, stop = min(pos, limit + 0x1))
end

function iswhitespace(bytes::DenseVector{UInt8}, pos::Integer)
    bytes[pos] ∈ (UInt8(' '), UInt8('\t'), UInt8('\n')) ||
        (bytes[pos] == 0xe2 && length(bytes) >= pos + 2 &&
         bytes[pos + 1] == 0x80 && 0x80 <= bytes[pos + 2] <= 0x8c)
end

function islongwhitespace(bytes::DenseVector{UInt8}, pos::Integer)
    bytes[pos] == 0xe2 && length(bytes) >= pos + 2 &&
        bytes[pos + 1] == 0x80 && 0x80 <= bytes[pos + 2] <= 0x8c
end

function containswhitespace(bytes::DenseVector{UInt8}, start::Integer, stop::Integer)
    for pos in start:stop
        iswhitespace(bytes, pos) && return true
    end
    false
end

const PLAIN_SKIP_TABLE = let canskip = zeros(Bool, 255)
    for c in UInt8('a'):UInt8('z')
        canskip[c] = true
    end
    for c in UInt8('A'):UInt8('Z')
        canskip[c] = true
    end
    for c in UInt8('0'):UInt8('9')
        canskip[c] = true
    end
    for c in "!\"&'(),.;?]}"
        canskip[UInt8(c)] = true
    end
    Tuple(canskip)
end

"""
    utf8bytes(chr::UInt8)

Return the number of bytes that the character starting with
the codeunit `chr` takes up, assuming UTF-8 encoding.

# Examples

```julia-repl
julia> utf8bytes(codeunit("a", 1))
1

julia> utf8bytes(codeunit("á", 1))
2

julia> utf8bytes(codeunit("þ", 1))
2

julia> utf8bytes(codeunit("\u200b", 1))
3

julia> utf8bytes(codeunit("🟣", 1))
4
```
"""
@inline function utf8bytes(chr::UInt8)
    clamp(leading_ones(chr), 1, 4)
end

@inline function utf8bytes(bytes::DenseVector{UInt8}, pos::I)::I where {I <: Integer}
    clamp(leading_ones(bytes[pos]) % I, I(1), I(4))
end

@inline function utf8next(bytes::DenseVector{UInt8}, pos::Integer)
    pos + utf8bytes(bytes, pos)
end

@inline function utf8prev(bytes::DenseVector{UInt8}, pos::Integer)
    pos - if pos > 4 && utf8bytes(bytes, pos - 0x4) == 4
        0x4
    elseif pos > 3 && utf8bytes(bytes, pos - 0x3) == 3
        0x3
    elseif pos > 2 && utf8bytes(bytes, pos - 0x2) == 2
        0x2
    else
        0x1
    end
end

function skipplain(bytes::DenseVector{UInt8}, start::I, multiline::Bool = false; limit::I = length(bytes) % I)::I where {I <: Integer}
    pos = start + utf8bytes(bytes, start)
    while pos <= limit
        chr = bytes[pos]
        if PLAIN_SKIP_TABLE[chr]
            pos += 1 % I
        elseif islongwhitespace(bytes, pos)
            pos += 3 % I
        elseif chr == UInt8('@') && pos > start + 1 && bytes[pos - 1] == UInt8('@')
            return pos - 1 % I
        elseif chr == UInt8('_') && pos > start + 2 && (hasprefix(bytes, pos - 3, "src") || hasprefix(bytes, pos - 3, "call"))
            return pos - 3 % I - (bytes[pos - 1] == UInt8('l')) % I
        elseif chr == UInt8(':') && ((bytes[pos - 1] ∉ (UInt8(' '), UInt8('\t'))) ||
            (pos > start + 2 && !islongwhitespace(bytes, pos - 3))) && limit > pos && !iswhitespace(bytes, pos + 1)
            start == 1 && return pos
            wp = pos
            while wp > start
                iswhitespace(bytes, wp) && return wp % I
                wp = utf8prev(bytes, wp)
            end
            pos += utf8bytes(chr) % I
        elseif chr ∈ (UInt8('\n'), UInt8('\r'))
            if multiline
                pos += 0x1
            else
                return pos
            end
        else
            clen = utf8bytes(chr) % I
            clen == 1 && pos > start && return pos - 0x1
            pos += clen
        end
    end
    limit + 0x1
end

"""
    charat(bytes::DenseVector{UInt8}, pos::Integer) -> Tuple{UInt32, Integer}

Return the Unicode codepoint at the position `pos` in the byte array `bytes`,
as well as the number of bytes that the codepoint takes up.

This assumes that `bytes` are the codepoints of a valid UTF-8 encoded string.

# Examples

```julia-repl
julia> cu = codeunits("aþ—🧮")
10-element Base.CodeUnits{UInt8, String}:
 0x61
 0xc3
 0xbe
 0xe2
 0x80
 0x94
 0xf0
 0x9f
 0xa7
 0xae

julia> charat(cu, 1)
(0x00000061, 1)

julia> charat(cu, 2)
(0x000000fe, 2)

julia> charat(cu, 4)
(0x00002014, 3)

julia> charat(cu, 7)
(0x0001f9ee, 4)
```
"""
function charat(bytes::DenseVector{UInt8}, pos::I) where {I <: Integer}
    b1 = bytes[pos]
    b1 < 0x80 && return UInt32(b1), 1 # ASCII fast-path
    len = utf8bytes(b1)
    if len == 2 && length(bytes) >= pos + 1
        b2 = bytes[pos + 1]
        UInt32(b1 & 0x1F) << 6 | b2 & 0x3f
    elseif len == 3 && length(bytes) >= pos + 2
        b2 = bytes[pos + 1]
        b3 = bytes[pos + 2]
        UInt32(b1 & 0x0F) << 12 | UInt32(b2 & 0x3f) << 6 | b3 & 0x3f
    elseif len == 4 && length(bytes) >= pos + 3
        b2 = bytes[pos + 1]
        b3 = bytes[pos + 2]
        b4 = bytes[pos + 3]
        UInt32(b1 & 0x07) << 18 | UInt32(b2 & 0x3f) << 12 |
            UInt32(b3 & 0x3f) << 6 | b4 & 0x3f
    else
        0x0000fffd
    end, len % I
end

"""
    skipwords(bytes::DenseVector{UInt8}, pos::Integer, extras) -> Integer

Skip over all word-constituent characters in `bytes` starting at `pos`.

If `extras` is provided, then any character in `extras` is also considered,
where `extras` is a tuple of characters as `UInt8`s or `Char`s.
"""
function skipwords(bytes::DenseVector{UInt8}, pos::I, extras::NTuple{N, C} = (); limit::I = length(bytes) % I)::I where {I <: Integer, N, C <: Union{Char, UInt8}}
    len, next = one(pos), pos
    alsoskip = map(UInt8, extras)
    while next <= limit
        b1 = bytes[next]
        if b1 < 0x7f
            len = one(pos)
            UInt8('a') <= b1 <= UInt8('z') ||
                UInt8('A') <= b1 <= UInt8('Z') ||
                UInt8('0') <= b1 <= UInt8('9') ||
                b1 ∈ alsoskip
        else
            chr, len = charat(bytes, next)
            1 <= Base.Unicode.category_code(chr) <= 4
        end || return next
        pos, next = next, next + len
    end
    pos
end

"""
    skipcharsets(bytes::DenseVector{UInt8}, pos::Integer, charsets...) -> Integer

Skip over all characters in `bytes` starting at `pos` that are in the given
character sets.

Each character set can be a single character or a range of characters.

# Examples

```julia-repl
julia> strv = codeunits("abc0123 .--");

julia> skipcharsets(strv, 1, 'a':'z')
4

julia> skipcharsets(strv, 1, 'a':'z', '0':'9')
8

julia> skipcharsets(strv, 1, 'a':'z', '0':'9', ' ')
9

julia> skipcharsets(strv, 1, 'a':'z', '0':'9', ' ', '-')
9

julia> skipcharsets(strv, 1, 'a':'z', '0':'9', ' ', '.')
10

julia> skipcharsets(strv, 1, 'a':'z', '0':'9', ' ', '.', '-')
12
```
"""
function skipcharsets(bytes::DenseVector{UInt8}, pos::Integer, charsets::Union{StepRange{Char}, Char}...; limit::Integer = length(bytes) % typeof(pos))
    skipranges = map(c -> if c isa Char UInt8(c) else
                         UInt8(first(c)):UInt8(last(c)) end,
                     charsets)
    len, next = one(pos), pos
    while next <= limit
        b1 = bytes[next]
        any(sr -> b1 in sr, skipranges) || return next
        pos, next = next, next + utf8bytes(bytes, next)
    end
    next + 0x1
end

"""
    skipbalanced(bytes::DenseVector{UInt8}, pos::Integer, bpair::Pair{Char, Char},
                 quotes::NTuple{N, Char} = (), escapechar::Union{Char, Nothing} = nothing) -> Integer

Skip over a balanced pair of characters (`bpair`) in `bytes` starting at `pos`.

It is expected that `bytes[pos]` is the opening character of the pair, from which
point all characters until as many closing characters of the pair have been
encountered as opening characters.

If `quotes` is provided, then the characters in `quotes` are considered as
additional opening characters, only characters outside quotes are considered.

Quotes and pairs can be escaped by `escapechar`, if provided.

# Examples

```julia-repl
julia> strv = codeunits("[some [nested] [text [deeply]] 'more] words\\' ] finally' an] end");

julia> skipbalanced(strv, 1, '[' => ']')
38

julia> skipbalanced(strv, 1, '[' => ']', ('\\'',))
48

julia> skipbalanced(strv, 1, '[' => ']', ('\\'',), '\\\\')
61
```
"""
function skipbalanced(bytes::DenseVector{UInt8}, pos::Integer, bpair::Pair{Char, Char};
                      quotes::NTuple{N, Char} = (), escapechar::Union{Char, Nothing} = nothing,
                      limit::Integer = length(bytes) % typeof(pos)) where {N}
    uopen = UInt8(first(bpair))
    uclose = UInt8(last(bpair))
    uquotes = map(q -> UInt8(q), quotes)
    uescape = UInt8(something(escapechar, '\0'))
    depth = 1
    currentquote = 0x00
    bytes[pos] == uopen || return zero(pos)
    pos += 0x1
    while true
        pos <= limit || break
        chr = bytes[pos]
        if !isnothing(escapechar) && chr == uescape && pos < limit
            pos += 0x1
        elseif currentquote != 0
            if chr == currentquote
                currentquote = 0x00
            end
        elseif currentquote == 0 && chr ∈ uquotes
            currentquote = chr
        elseif chr == uopen
            depth += 1
        elseif chr == uclose
            depth -= 1
        end
        pos += utf8bytes(bytes, pos)
        depth == 0 && return pos
    end
    zero(pos)
end

function ischarat(bytes::DenseVector{UInt8}, pos::Integer, char::Char; limit::Integer = length(bytes) % typeof(pos))
    pos > limit && return false
    bytes[pos] == UInt8(char)
end

function islineend(bytes::DenseVector{UInt8}, pos::Integer)
    pos > length(bytes) || bytes[pos] ∈ (UInt8('\r'), UInt8('\n'))
end

function lineend(bytes::DenseVector{UInt8}, pos::I; limit::I = length(bytes) % I)::I where {I <: Integer}
    for p in pos:limit
        bytes[p] ∈ (UInt8('\r'), UInt8('\n')) && return p
    end
    limit + 0x1
end

function hasprefix(bytes::DenseVector{UInt8}, start::Integer, pattern::String; limit::Integer = length(bytes) % typeof(start))
    limit >= start + ncodeunits(pattern) - 1 || return false
    for (i, c) in enumerate(codeunits(pattern))
        b = bytes[start + i - 1]
        b == c || b == c ⊻ 0x20 || return false
    end
    true
end

function countsame(bytes::DenseVector{UInt8}, pos::I, char::Char; limit::I = length(bytes) % I)::I where {I <: Integer}
    uchar = UInt8(char)
    for p in pos:limit
        bytes[p] != uchar && return p - pos
    end
    limit + 0x1
end

function nextchar(bytes::DenseVector{UInt8}, pos::I, char::UInt8; limit::I = length(bytes) % I)::I where {I <: Integer}
    for p in pos:limit
        bytes[p] == char && return p
    end
    limit + 0x1
end

nextchar(bytes::DenseVector{UInt8}, pos::Integer, char::Char; limit::Integer = length(bytes) % typeof(pos)) =
    nextchar(bytes, pos, UInt8(char); limit)

function nextchar(bytes::DenseVector{UInt8}, pos::I, chars::NTuple{N, C}; limit::I = length(bytes) % I)::I where {I <: Integer, N, C <: Union{UInt8, Char}}
    ichars = map(UInt8, chars)
    for p in pos:limit
        bytes[p] ∈ ichars && return p
    end
    limit + 0x1
end

function untilwhitespace(bytes::DenseVector{UInt8}, pos::I; limit::I = length(bytes) % I) where {I <: Integer}
    for p in pos:limit
        iswhitespace(bytes, p) && return p - 0x1
    end
    limit
end

function skipnewlines(bytes::DenseVector{UInt8}, pos::I; limit::I = length(bytes) % I)::Tuple{I, Int} where {I <: Integer}
    newlines = Int(pos == 1)
    while true
        if bytes[pos] == UInt8('\n')
            pos += 0x1
        elseif bytes[pos] == UInt8('\r') && ischarat(bytes, pos + 0x1, '\n')
            pos += 0x2
        else
            wsend = skipspaces(bytes, pos).stop
            if wsend > pos && wsend == lineend(bytes, pos)
                pos = wsend
                newlines -= 1
            else
                break
            end
        end
        newlines += 1
        pos <= limit || return limit, newlines - 1
    end
    pos, newlines
end

"""
    word2tag(bytes::DenseVector{UInt8}, start::Integer, stop::Integer) -> UInt8

Return a case-insensitive of the (assumed ASCII) word in `bytes` between `start`
and `stop`.
"""
function word2tag(bytes::DenseVector{UInt8}, start::Integer, stop::Integer)
    h = UInt64(0)
    for pos in start:stop
        b = bytes[pos]
        if UInt8('A') <= b <= UInt8('Z')
            b |= 0x20
        end
        h = hash(b, h)
    end
    h8 = reinterpret(NTuple{8, UInt8}, h)
    reduce(xor, h8)
end
