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
    state.position >= length(lex.input) && return
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

function lexnext(state::LexerState, bytes::DenseVector{UInt8}, start::UInt32)
    linestart, newlines = @inline skipnewlines(bytes, start)
    skipws = skiphspace(bytes, linestart)
    pos = skipws.stop
    chr = bytes[pos]
    next = if newlines > 2 && K"footnote_definition" ∈ state.ctx
        Token(K">footnote_definition", linestart, pos), start
    elseif newlines != 0
        if chr == UInt8('*') && ischarat(bytes, pos + countsame(bytes, pos, UInt8('*')), ' ')
            lex_heading(state, bytes, pos)
        elseif chr == UInt8(':')
            lex_drawer(state, bytes, pos)
        elseif chr == UInt8('[') && pos == linestart && K"footnote_definition" ∈ state.restriction
            lex_footnotedef(state, bytes, pos)
        elseif chr == UInt8('#') && ischarat(bytes, pos + 1, '+') && (state.ctx in (K"#+" ⊻ K"keyword") || !isempty(K"#+" & restriction))
            lex_hashplus(state, bytes, pos)
        end
    end
    if isnothing(next)
        pos = @inline skipplain(bytes, pos)
        Token(K"plaintext", linestart, pos), (pos + 1) % UInt32
    else
        token, pos = next
        token, pos % UInt32
    end
end


# Element lexing

function lex_heading(::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    depth = countsame(bytes, pos, UInt8('*'))
    Token(settag(K"heading", depth % UInt8), pos, lineend(bytes, pos) - 1),
    pos + depth
end

function lex_drawer(state::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    kind, drawend = if state.lastelement ∈ K"heading" && hasprefix(bytes, pos, ":properties:")
        K"<property_drawer", pos + ncodeunits(":properties:")
    elseif hasprefix(bytes, pos, ":end:")
        if K"property_drawer" ∈ state.ctx
            K">property_drawer"
        elseif K"drawer" ∈ state.ctx
            K">drawer"
        else
            return
        end, pos + ncodeunits(":end:")
    elseif K"property_drawer" ∈ state.ctx
        nameend = nextindex(bytes, pos + 1, (' ', '\t'))
        bytes[nameend - 1] == UInt8(':') || return
        K"node_property", lineend(bytes, nameend)
    elseif K"drawer" ∈ state.restriction
        nameend = nextindex(bytes, pos + 1, ':')
        nameend == skipwords(bytes, pos + 1, ('-', '_')) || return
        K"<drawer", nameend + 1
    else
        return
    end
    drawend = skiphspace(bytes, drawend).stop
    if islineend(bytes, drawend)
        Token(kind, pos, drawend - 1), drawend
    end
end

function lex_footnotedef(::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    hasprefix(bytes, pos, "[fn:") || return
    fnend = skipwords(bytes, pos + ncodeunits("[fn:"), ('-', '_'))
    bytes[fnend] == UInt8(']') || return
    Token(K"<footnote_definition", pos, fnend), fnend + 1
end

function lex_hashplus(state::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    @something(lex_block(state, bytes, pos),
               if K"dynamic_block" in state.ctx
                   lex_dynamicblock(state, bytes, pos)
               end,
               if K"keyword" in state.restriction
                   lex_keyword(state, bytes, pos)
               end,
               Some(nothing))
end

function lex_block((; ctx)::LexerState, bytes::DenseVector{UInt8}, start::UInt32)
    mode, pos = if hasprefix(bytes, start, "#+begin_")
        K"<", start + ncodeunits("#+begin_")
    elseif hasprefix(bytes, start, "#+end_")
        K">", start + ncodeunits("#+end_")
    else
        return
    end
    lend = lineend(bytes, pos)
    nameend = untilwhitespace(bytes, pos)
    containswhitespace(bytes, pos, nameend) && return
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
        return
    end
    ws = skiphspace(bytes, pos + prefixlen)
    if mode == ">" && !islineend(bytes, ws.stop)
        return
    end
    nameend = untilwhitespace(bytes, pos + prefixlen)
    containswhitespace(bytes, pos, nameend) && return
    lend = lineend(bytes, pos)
    tag = word2tag(bytes, pos + prefixlen, nameend - 1)
    Token(settag(K"dynamic_block" | mode, tag), pos, lend - 1), lend
end

function lex_keyword(::LexerState, bytes::DenseVector{UInt8}, pos::UInt32)
    if !hasprefix(bytes, pos, "#+")
        return
    end
    nameend = nextindex(bytes, pos, ':')
    nameend > length(bytes) && return
    containswhitespace(bytes, pos, nameend) && return
    lend = lineend(bytes, pos)
    tag = word2tag(bytes, pos + 2, nameend - 1)
    Token(settag(K"keyword", tag), pos, lend - 1), lend
end


# Object lexing


# Utility functions

function skiphspace(bytes::DenseVector{UInt8}, pos::Integer)
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
    (width = wskipped, stop = min(pos, length(bytes)) % UInt32)
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
function utf8bytes(chr::UInt8)
    clamp(leading_ones(chr), 1, 4)
end

function skipplain(bytes::DenseVector{UInt8}, start::Integer)
    pos = start + utf8bytes(bytes[start])
    while pos < length(bytes)
        chr = bytes[pos]
        if PLAIN_SKIP_TABLE[chr]
            pos += 1
        elseif islongwhitespace(bytes, pos)
            pos += 3
        elseif chr == UInt8('@') && bytes[pos - 1] == UInt8('@')
            return pos - 2
        elseif chr == UInt8('_') && pos > start + 2 && (hasprefix(bytes, pos - 3, "src") || hasprefix(bytes, pos - 3, "call"))
            return pos - 3 - Bool(bytes[pos - 1] == UInt8('l'))
        elseif chr == UInt8(':') && ((bytes[pos - 1] ∉ (UInt8(' '), UInt8('\t'))) && (pos > start + 2 && !islongwhitespace(bytes, pos - 3)))
            for wp in pos:-1:start+1
                if iswhitespace(bytes, wp)
                    return wp
                end
            end
            pos += utf8bytes(chr)
        else
            clen = utf8bytes(chr)
            clen == 1 && pos > start + 1 && return pos - 1
            pos += clen
        end
    end
    length(bytes)
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
function charat(bytes::DenseVector{UInt8}, pos::Integer)
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
    end, len
end

"""
    skipwords(bytes::DenseVector{UInt8}, pos::Integer, extras) -> Integer

Skip over all word-constituent characters in `bytes` starting at `pos`.

If `extras` is provided, then any character in `extras` is also considered,
where `extras` is a tuple of characters as `UInt8`s or `Char`s.
"""
function skipwords(bytes::DenseVector{UInt8}, pos::Integer, extras::NTuple{N, C} = ()) where {N, C <: Union{Char, UInt8}}
    len, next = 1, pos
    alsoskip = map(UInt8, extras)
    while next <= length(bytes)
        b1 = bytes[next]
        if b1 < 0x7f
            len = 1
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

function ischarat(bytes::DenseVector{UInt8}, pos::Integer, char::Char)
    length(bytes) >= pos || return false
    bytes[pos] == UInt8(char)
end

function islineend(bytes::DenseVector{UInt8}, pos::Integer)
    pos >= length(bytes) || bytes[pos] ∈ (UInt8('\r'), UInt8('\n'))
end

function lineend(bytes::DenseVector{UInt8}, pos::Integer)
    for p in pos:length(bytes)
        bytes[p] ∈ (UInt8('\r'), UInt8('\n')) && return p
    end
    length(bytes) + 1
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

function countsame(bytes::DenseVector{UInt8}, pos::Integer, char::UInt8)
    for p in pos:length(bytes)
        bytes[p] != char && return p - pos
    end
    length(bytes) + 1
end

function nextindex(bytes::DenseVector{UInt8}, pos::Integer, char::UInt8)
    for p in pos:length(bytes)
        bytes[p] == char && return p
    end
    length(bytes) + 1
end

nextindex(bytes::DenseVector{UInt8}, pos::Integer, char::Char) =
    nextindex(bytes, pos, UInt8(char))

function nextindex(bytes::DenseVector{UInt8}, pos::Integer, chars::NTuple{N, C}) where {N, C <: Union{UInt8, Char}}
    ichars = map(UInt8, chars)
    for p in pos:length(bytes)
        bytes[p] ∈ ichars && return p
    end
    length(bytes) + 1
end

function untilwhitespace(bytes::DenseVector{UInt8}, pos::Integer)
    for p in pos:length(bytes)
        iswhitespace(bytes, p) && return p - 1
    end
    length(bytes)
end

function skipnewlines(bytes::DenseVector{UInt8}, pos::Integer)
    newlines = Int(pos == 1)
    while true
        if bytes[pos] == UInt8('\n')
            pos += 1
        elseif bytes[pos] == UInt8('\r') && ischarat(bytes, pos + 1, UInt8('\n'))
            pos += 2
        else
            wsend = skiphspace(bytes, pos).stop
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
