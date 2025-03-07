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
    last::Kind
end

Base.eltype(::Type{<:Lexer}) = Token
Base.IteratorSize(::Type{<:Lexer}) = Base.SizeUnknown()

function Base.iterate(lex::Lexer)
    state = LexerState(firstindex(lex.input), K"", K"")
    iterate(lex, state)
end

function Base.iterate(lex::Lexer, (; position, ctx, last)::LexerState)
    position >= length(lex.input) && return
    restriction = restrictions(ctx)
    local token
    while position <= length(lex.input)
        token, position = lexnext(lex.input, position, ctx, restriction, last)
        if token.kind == K"plaintext"
            last = token.kind
        elseif token.kind == K"heading"
            ctx = K""
            break
        elseif token.kind ∈ K"block"
            break
        elseif isbegin(token.kind) || isend(token.kind)
            ctx = ctx ⊻ plain(token.kind)
            break
        else
            break
        end
    end
    token, LexerState(position, ctx, token.kind)
end


# Lexers

function lexnext(bytes::DenseVector{UInt8}, start::UInt32, ctx::Kind, restrictions::Kind, last::Kind)
    newline, blankline = false, false
    while true
        if bytes[start] == UInt8('\n')
            blankline = newline
            newline = true
            start += 1
        elseif bytes[start] == UInt8('\r') && isthischar(bytes, start + 1, UInt8('\n'))
            blankline = newline
            newline = true
            start += 2
        else
            break
        end
    end
    skipws = skiphspace(bytes, start)
    pos = skipws.stop
    chr = bytes[pos]
    next = if newline
        if chr == UInt8('*') && isthischar(bytes, pos + countsame(bytes, pos, UInt8('*')), ' ')
            lex_heading(bytes, pos)
        elseif chr == UInt8('#') && isthischar(bytes, pos + 1, '+') && (ctx in (K"#+" ⊻ K"keyword") || !isempty(K"#+" & restrictions))
            lex_hashplus(bytes, pos, ctx, restrictions)
        end
    end
    if isnothing(next)
        pos = skipplain(bytes, pos)
        Token(K"plaintext", start, pos), (pos + 1) % UInt32
    else
        token, pos = next
        token, pos % UInt32
    end
end

function lex_heading(bytes::DenseVector{UInt8}, pos::UInt32)
    depth = countsame(bytes, pos, UInt8('*'))
    Token(settag(K"heading", depth % UInt8), pos, lineend(bytes, pos) - 1),
    pos + depth
end

function lex_hashplus(bytes::DenseVector{UInt8}, pos::UInt32, ctx::Kind, res::Kind)
    @something(lex_block(bytes, pos, ctx),
               if K"dynamic_block" in ctx
                   lex_dynamicblock(bytes, pos)
               end,
               if K"keyword" in res
                   lex_keyword(bytes, pos)
               end,
               Some(nothing))
end

function lex_block(bytes::DenseVector{UInt8}, start::UInt32, ctx::Kind)
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

function lex_dynamicblock(bytes::DenseVector{UInt8}, pos::UInt32)
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

function lex_keyword(bytes::DenseVector{UInt8}, pos::UInt32)
    if !hasprefix(bytes, pos, "#+")
        return
    end
    nameend = nextindex(bytes, pos, UInt8(':'))
    nameend > length(bytes) && return
    containswhitespace(bytes, pos, nameend) && return
    lend = lineend(bytes, pos)
    tag = word2tag(bytes, pos + 2, nameend - 1)
    Token(settag(K"keyword", tag), pos, lend - 1), lend
end


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
    (width = wskipped, stop = pos % UInt32)
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
    for c in (UInt8('.'), UInt8(','), UInt8('!'), UInt8('?'), UInt8('('), UInt8(')'))
        canskip[c] = true
    end
    for c in (UInt8(' '), UInt8('\t'))
        canskip[c] = true
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

function isthischar(bytes::DenseVector{UInt8}, pos::Integer, char::Char)
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

function untilwhitespace(bytes::DenseVector{UInt8}, pos::Integer)
    for p in pos:length(bytes)
        iswhitespace(bytes, p) && return p - 1
    end
    length(bytes)
end

function word2tag(bytes::DenseVector{UInt8}, start::Integer, stop::Integer)
    h = UInt64(0)
    for pos in start:stop
        h = hash(bytes[pos], h)
    end
    h8 = reinterpret(NTuple{8, UInt8}, h)
    reduce(xor, h8)
end
