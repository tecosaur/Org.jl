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

Base.eltype(::Type{<:Lexer}) = Token
Base.IteratorSize(::Type{<:Lexer}) = Base.SizeUnknown()

function Base.iterate(lex::Lexer)
    state = LexerState(firstindex(lex.input), K"", restrictions(K""), K"")
    iterate(lex, state)
end

function Base.iterate(lex::Lexer, state::LexerState)
    state.position <= length(lex.input) || return
    (; position, ctx, restriction, lastelement) = state
    local token
    while position <= length(lex.input)
        token, position = @inline lexnext(state, lex.input, position)
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

const U1 = UInt32(1)

const NONE_TOKEN = Token(K"", 0, 0), UInt32(0)

function lexnext(state::LexerState, bytes::DenseVector{UInt8}, start::UInt32)::Tuple{Token, UInt32}
    linestart, newlines = @inline skipnewlines(bytes, start)
    skipws = skipspaces(bytes, linestart)
    pos = skipws.stop
    chr = bytes[pos]
    next = if newlines > 2 && K"footnote_definition" ∈ state.ctx
        Token(K">footnote_definition", linestart, pos), start
    elseif newlines != 0
        if chr == UInt8('*') && ischarat(bytes, pos + countsame(bytes, pos, '*'), ' ')
            lex_heading(state, bytes, pos)
        elseif chr == UInt8(':')
            lex_drawer(state, bytes, pos)
        elseif chr == UInt8('[') && pos == linestart && K"footnote_definition" ∈ state.restriction
            lex_footnotedef(state, bytes, pos)
        elseif chr == UInt8('|')
            if K"table_row" ∈ state.ctx
                Token(K"<table_cell", pos + U1, pos + U1), pos + U1
            elseif K"table" ∈ state.ctx
                if ischarat(bytes, pos + U1, '-')
                    lend = lineend(bytes, pos)
                    Token(K"table_row[1]", pos, lend), lend + U1
                else
                    Token(K"<table_row", pos, pos), pos
                end
            elseif K"table" ∈ state.restriction
                Token(K"<table", pos, pos), pos
            else
                NONE_TOKEN
            end
        elseif chr == UInt8('#') && ischarat(bytes, pos + U1, '+') && (state.ctx in (K"#+" ⊻ K"keyword") || !isempty(K"#+" & state.restriction))
            lex_hashplus(state, bytes, pos)
        else
            if K"item" ∈ state.restriction
                lex_item(state, bytes, pos, skipws.width)
            else
                NONE_TOKEN
            end
        end
    else # No newlines
        if K"table" ∈ state.ctx && islineend(bytes, pos + U1)
            if K"table_cell" ∈ state.ctx
                Token(K">table_cell", pos, pos), pos
            elseif K"table_row" ∈ state.ctx
                Token(K">table_row", pos, pos), pos
            elseif K"table" ∈ state.ctx
                Token(K">table", pos, pos), pos + U1
            else
                NONE_TOKEN
            end
        elseif K"table_row" ∈ state.ctx
            if K"table_cell" ∈ state.ctx
                cellend = nextchar(bytes, pos, ('|', '\n', '\r'))
                cellend -= bytes[cellend] ∈ ('\n', '\r')
                Token(K">table_cell", cellend, cellend), cellend
            else
                Token(K"<table_cell", pos + U1, pos + U1), pos + U1
            end
        else
            NONE_TOKEN
        end
    end
    if next == NONE_TOKEN
        pos = @inline skipplain(bytes, pos)
        Token(K"plaintext", linestart, pos), pos % UInt32 + U1
    else
        token, pos = next
        token, pos % UInt32
    end
end


# Greater element lexing

function lex_heading(::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    depth = countsame(bytes, pos, '*')
    Token(settag(K"heading", depth % UInt8), pos, lineend(bytes, pos) - 1),
    pos + depth
end

function lex_drawer(state::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    kind, drawend = if state.lastelement ∈ K"heading" && hasprefix(bytes, pos, ":properties:")
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
        nameend = nextchar(bytes, pos + U1, (' ', '\t'))
        bytes[nameend - 1] == UInt8(':') || return NONE_TOKEN
        K"node_property", lineend(bytes, nameend)
    elseif K"drawer" ∈ state.restriction
        nameend = nextchar(bytes, pos + U1, ':')
        nameend == skipwords(bytes, pos + U1, ('-', '_')) || return NONE_TOKEN
        K"<drawer", nameend + U1
    else
        return NONE_TOKEN
    end
    drawend = skipspaces(bytes, drawend).stop
    islineend(bytes, drawend) || return NONE_TOKEN
    Token(kind, pos, drawend - U1), drawend
end

function lex_footnotedef(::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    hasprefix(bytes, pos, "[fn:") || return NONE_TOKEN
    fnend = skipwords(bytes, pos + ncodeunits("[fn:") % UInt32, ('-', '_'))
    bytes[fnend] == UInt8(']') || return NONE_TOKEN
    Token(K"<footnote_definition", pos, fnend), fnend + U1
end

function lex_item(::LexerState, bytes::DenseVector{UInt8}, start::UInt32, column::Integer)
    function read_bullet(bytes::DenseVector{UInt8}, pos::Integer)
        ord, pos = if bytes[pos] ∈ (UInt8('-'), UInt8('+'), UInt8('*'))
            false, pos + U1
        else
            bulletend = nextchar(bytes, pos, ('.', ')', '\n', '\r'))
            if bulletend >= length(bytes) ||
                bytes[bulletend] ∈ (UInt8('\n'), UInt8('\r')) ||
                nextchar(bytes, pos, (' ', '\n', '\r')) < bulletend
                return false, zero(pos)
            end
            bulletend == skipcharsets(bytes, pos, '0':'9') ||
                bulletend == skipcharsets(bytes, pos, 'a':'z', 'A':'Z') ||
                return false, zero(pos)
            true, bulletend + U1
        end
        bytes[pos] ∈ (UInt8(' '), UInt8('\t')) || return false, zero(pos)
        ord, skipspaces(bytes, pos).stop
    end
    ordered, pos = read_bullet(bytes, start)
    pos != 0 || return NONE_TOKEN
    contentend = lineend(bytes, pos)
    while contentend < length(bytes)
        pos, newlines = skipnewlines(bytes, contentend)
        newlines >= 2 && break
        ws = skipspaces(bytes, pos)
        if ws.width <= column
            break
        elseif last(read_bullet(bytes, ws.stop)) != 0
            break
        else
            contentend = lineend(bytes, pos)
        end
    end
    Token(settag(K"item", UInt8(column)), start, contentend), contentend + U1
end

function lex_hashplus(state::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    @something(lex_block(state, bytes, pos),
               if K"dynamic_block" in state.ctx
                   lex_dynamicblock(state, bytes, pos)
               end,
               if K"keyword" in state.restriction
                   lex_keyword(state, bytes, pos)
               end,
               NONE_TOKEN)
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
            return if mode == K"<" && kind ∉ ctx
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

function lex_dynamicblock(::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    mode, prefixlen = if hasprefix(bytes, pos, "#+begin:")
        K"<", ncodeunits("#+begin:")
    elseif hasprefix(bytes, pos, "#+end:")
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


# Object lexing


# Utility functions

function skipspaces(bytes::DenseVector{UInt8}, pos::Integer)
    wskipped = 0
    while pos <= length(bytes)
        if bytes[pos] == UInt8(' ')
            pos += 1
            wskipped += 1
        elseif bytes[pos] == UInt8('\t')
            pos += 1
            wskipped += 8
        elseif bytes[pos] == 0xe2 && length(bytes) >= pos + 2 &&
            bytes[pos + 1] == 0x80 && 0x80 <= bytes[pos + 2] <= 0x8c
            if bytes[pos + 2] < 0x8b
                wskipped += 1
            end
            pos += 3
        else
            break
        end
    end
    @NamedTuple{width::Int, stop::UInt32}(
        (wskipped, min(pos, length(bytes)) % UInt32))
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

function skipplain(bytes::DenseVector{UInt8}, start::I)::I where {I <: Integer}
    pos = start + utf8bytes(bytes, start)
    while pos < length(bytes)
        chr = bytes[pos]
        if PLAIN_SKIP_TABLE[chr]
            pos += one(pos)
        elseif islongwhitespace(bytes, pos)
            pos += 3 * one(pos)
        elseif chr == UInt8('@') && bytes[pos - 1] == UInt8('@')
            return pos - 2 * one(pos)
        elseif chr == UInt8('_') && pos > start + 2 && (hasprefix(bytes, pos - 3, "src") || hasprefix(bytes, pos - 3, "call"))
            return pos - 3 * one(pos) - Bool(bytes[pos - 1] == UInt8('l'))
        elseif chr == UInt8(':') && ((bytes[pos - 1] ∉ (UInt8(' '), UInt8('\t'))) && (pos > start + 2 && !islongwhitespace(bytes, pos - 3)))
            for wp in pos:-1:start+1
                if iswhitespace(bytes, wp)
                    return wp % I
                end
            end
            pos += utf8bytes(chr) % I
        else
            clen = utf8bytes(chr) % I
            clen == 1 && pos > start + 1 && return pos - one(pos)
            pos += clen
        end
    end
    length(bytes) % I
end

"""
    charat(bytes::DenseVector{UInt8}, pos::Integer) -> UInt32

Return the Unicode codepoint at the position `pos` in the byte array `bytes`.

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
0x00000061

julia> charat(cu, 2)
0x000000fe

julia> charat(cu, 4)
0x00002014

julia> charat(cu, 7)
0x0001f9ee
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
function skipwords(bytes::DenseVector{UInt8}, pos::I, extras::NTuple{N, C} = ())::I where {I <: Integer, N, C <: Union{Char, UInt8}}
    len, next = one(pos), pos
    alsoskip = map(UInt8, extras)
    while next <= length(bytes)
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
        end || return next % I
        pos, next = next, next + len
    end
    pos % I
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
function skipcharsets(bytes::DenseVector{UInt8}, pos::Integer, charsets::Union{StepRange{Char}, Char}...)
    skipranges = map(c -> if c isa Char UInt8(c) else
                         UInt8(first(c)):UInt8(last(c)) end,
                     charsets)
    len, next = 1, pos
    while next <= length(bytes)
        b1 = bytes[next]
        any(sr -> b1 in sr, skipranges) || return next
        pos, next = next, next + utf8bytes(b1)
    end
    next
end

function ischarat(bytes::DenseVector{UInt8}, pos::Integer, char::Char)
    length(bytes) >= pos || return false
    bytes[pos] == UInt8(char)
end

function islineend(bytes::DenseVector{UInt8}, pos::Integer)
    pos > length(bytes) || bytes[pos] ∈ (UInt8('\r'), UInt8('\n'))
end

function lineend(bytes::DenseVector{UInt8}, pos::I)::I where {I <: Integer}
    for p in pos:length(bytes)
        bytes[p] ∈ (UInt8('\r'), UInt8('\n')) && return p % I
    end
    (length(bytes) + 1) % I
end

function hasprefix(bytes::DenseVector{UInt8}, start::Integer, pattern::String)
    length(bytes) >= start + ncodeunits(pattern) - 1 || return false
    for (i, c) in enumerate(codeunits(pattern))
        if bytes[start + i - 1] == c
        elseif UInt8('A') <= c <= UInt8('Z') &&
            bytes[start + i - 1] == c ⊻ 0x20
        else
            return false
        end
    end
    true
end

function countsame(bytes::DenseVector{UInt8}, pos::I, char::Char)::I where {I <: Integer}
    uchar = UInt8(char)
    for p in pos:length(bytes)
        bytes[p] != uchar && return (p - pos) % I
    end
    (length(bytes) + 1) % I
end

function nextchar(bytes::DenseVector{UInt8}, pos::I, char::UInt8)::I where {I <: Integer}
    for p in pos:length(bytes)
        bytes[p] == char && return p % I
    end
    (length(bytes) + 1) % I
end

nextchar(bytes::DenseVector{UInt8}, pos::Integer, char::Char) =
    nextchar(bytes, pos, UInt8(char))

function nextchar(bytes::DenseVector{UInt8}, pos::I, chars::NTuple{N, C})::I where {I <: Integer, N, C <: Union{UInt8, Char}}
    ichars = map(UInt8, chars)
    for p in pos:length(bytes)
        bytes[p] ∈ ichars && return p % I
    end
    (length(bytes) + 1) % I
end

function untilwhitespace(bytes::DenseVector{UInt8}, pos::I) where {I <: Integer}
    for p in pos:length(bytes)
        iswhitespace(bytes, p) && return (p - 1) % I
    end
    length(bytes) % I
end

function skipnewlines(bytes::DenseVector{UInt8}, pos::I)::Tuple{I, Int} where {I <: Integer}
    newlines = Int(pos == 1)
    while true
        if bytes[pos] == UInt8('\n')
            pos += 1 % I
        elseif bytes[pos] == UInt8('\r') && ischarat(bytes, pos + U1, '\n')
            pos += 2 % I
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
        pos <= length(bytes) || return length(bytes), newlines - 1
    end
    pos, newlines
end

function word2tag(bytes::DenseVector{UInt8}, start::Integer, stop::Integer)
    h = UInt64(0)
    for pos in start:stop
        h = hash(bytes[pos], h)
    end
    h8 = reinterpret(NTuple{8, UInt8}, h)
    reduce(xor, h8)
end
