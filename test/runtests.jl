using Org
using Test

using Org: Lexer, LexerState, Token, Kind, @K_str

# JET doesn't support pre-release versions
@static if isempty(VERSION.prerelease)
    using JET
else
    macro test_call(_ex) true end
    macro test_opt(_ex) true end
end

@testset "Syntax" begin
    @test K"item|list" == Kind("item") | Kind("list")
    @test K"block[22]" == Kind("block", UInt8(22))
    @test K"<block" == Kind("block", UInt8(0), start = true)
    @test K">block" == Kind("block", UInt8(0), stop = true)
    @test Org.tag(Org.settag(K"item", 0x12)) == 0x12
    @test Org.plain(K"<block[22]") == K"block"
    @test sprint(show, K"macro") == "K\"macro\""
    @test sprint(show, K"<macro") == "K\"<macro\""
    @test sprint(show, K">macro[16]") == "K\">macro[16]\""
    @test_opt Kind("block")
    @test_opt Org.kind_number(K"")
    @test_opt K"markup" in K"objects"
    @test_opt Org.restrictions(K"paragraph")
end

@testset "Lexing" begin
    @testset "Headings" begin
        @test collect(Lexer("* heading")) ==
            [Token(K"heading[1]", 1, 9)]
        @test collect(Lexer("*** heading")) ==
            [Token(K"heading[3]", 1, 11)]
    end
    @testset "Blocks" begin
        @testset "Greater blocks" begin
            @test collect(Lexer("""
            #+begin_block
            content
            #+end_block
            """)) ==
                [Token(K"<block[30]", 1, 13),
                Token(K">block[30]", 23, 33)]
            @test collect(Lexer("""
            #+BEGIN_BLOCK parameters
            content
            #+END_BLOCK
            """)) ==
                [Token(K"<block[30]", 1, 24),
                Token(K">block[30]", 34, 44)]
            @test collect(Lexer("""
            #+begin_block
            #+begin_other
            content
            #+end_other
            #+end_block
            """)) ==
                [Token(K"<block[30]", 1, 13)
                 Token(K"<block[41]", 15, 27)
                 Token(K">block[41]", 37, 47)
                 Token(K">block[30]", 49, 59)]
        end
        @testset "Dynamic blocks" begin
            @test collect(Lexer("""
            #+begin: name
            content
            #+end:
            """)) ==
                [Token(K"<dynamic_block", 1, 13),
                 Token(K">dynamic_block", 23, 28)]
        end
        @testset "Lesser blocks" begin
            @test collect(Lexer("""
            #+begin_src
            content
            #+end_src
            """)) ==
                [Token(K"<source_block", 1, 11),
                 Token(K">source_block", 21, 29)]
            @test collect(Lexer("""
            #+begin_src stuff
            #+begin_src again
            #+end_src stuff
            #+end_src again
            #+end_src extra
            """)) ==
                [Token(K"<source_block", 1, 17),
                 Token(K">source_block", 37, 51)]
            @test collect(Lexer("""
            #+begin_export html
            <b>content</b>
            #+end_export
            """)) ==
                [Token(K"<export_block", 1, 19),
                 Token(K">export_block", 36, 47)]
        end
    end
    @testset "Drawers" begin
        @testset "Standard drawers" begin
            @test collect(Lexer("""
            :drawer:
            content
            :end:
            """)) ==
                [Token(K"<drawer", 1, 8),
                 Token(K">drawer", 18, 22)]
            @test collect(Lexer("""
            :drawer:
            content
            :notadrawer:
            more
            :end:
            """)) ==
                [Token(K"<drawer", 1, 8),
                 Token(K">drawer", 36, 40)]
        end
        @testset "Property drawers" begin
            @test collect(Lexer("""
            * Heading
            :PROPERTIES:
            :node: value
            :END:
            """)) ==
                [Token(K"heading[1]", 1, 9),
                 Token(K"<property_drawer", 11, 22),
                 Token(K"node_property", 24, 35),
                 Token(K">property_drawer", 37, 41)]
            @test collect(Lexer("""
            * Heading
            SCHEDULED: <2025-03-15 Sat>
            :PROPERTIES:
            :node: value
            :END:
            """)) ==
                [Token(K"heading[1]", 1, 9),
                 Token(K"planning[1]", 11, 38),
                 Token(K"<property_drawer", 39, 50),
                 Token(K"node_property", 52, 63),
                 Token(K">property_drawer", 65, 69)]
        end
    end
    @testset "Footnote defs" begin
        @test collect(Lexer("[fn:1] stuff")) ==
            [Token(K"<footnote_definition", 1, 6)]
        @test collect(Lexer("[fn:1] stuff\n[fn:2] more")) ==
            [Token(K"<footnote_definition", 1, 6),
             Token(K">footnote_definition", 12, 12),
             Token(K"<footnote_definition", 14, 19)]
        @test collect(Lexer("[fn:1] stuff\n\n\nmore")) ==
            [Token(K"<footnote_definition", 1, 6),
             Token(K">footnote_definition", 12, 12)]
    end
    @testset "Items" begin
        @test collect(Lexer("+ item")) == [Token(K"item[1]", 1, 7)]
        @test collect(Lexer("  + item")) == [Token(K"item[3]", 3, 9)]
        @test collect(Lexer("- item")) == [Token(K"item[1]", 1, 7)]
        @test collect(Lexer(" * item")) == [Token(K"item[2]", 2, 8)]
        @test collect(Lexer("+ item\nmore")) == [Token(K"item[1]", 1, 7)]
        @test collect(Lexer("+ item\n more")) == [Token(K"item[1]", 1, 13)]
        @test collect(Lexer("+ item\n  more")) == [Token(K"item[1]", 1, 14)]
        @test collect(Lexer("+ item\n  \n  more")) == [Token(K"item[1]", 1, 17)]
        @test collect(Lexer("+ item\n\n  more")) == [Token(K"item[1]", 1, 15)]
        @test collect(Lexer("+ item\n\n\n  more")) == [Token(K"item[1]", 1, 7)]
        @test collect(Lexer(" + item\n more")) == [Token(K"item[2]", 2, 8)]
        @test collect(Lexer(" + item\n  more")) == [Token(K"item[2]", 2, 15)]
        @test collect(Lexer("1. item")) == [Token(K"item[1]", 1, 8)]
        @test collect(Lexer("12) item")) == [Token(K"item[1]", 1, 9)]
        @test collect(Lexer("a. item")) == [Token(K"item[1]", 1, 8)]
        @test collect(Lexer("ab) item")) == [Token(K"item[1]", 1, 9)]
    end
    @testset "Tables" begin
        @test collect(Lexer("|")) ==
            [Token(K"<table", 1, 1),
             Token(K"<table_row", 1, 1)]
        @test collect(Lexer("| cell")) ==
            [Token(K"<table", 1, 1),
             Token(K"<table_row", 1, 1),
             Token(K"<table_cell", 3, 3),
             Token(K">table_cell", 6, 6),
             Token(K">table_row", 6, 6)]
        @test collect(Lexer("| cell\ntext")) ==
            [Token(K"<table", 1, 1),
             Token(K"<table_row", 1, 1),
             Token(K"<table_cell", 3, 3),
             Token(K">table_cell", 6, 6),
             Token(K">table_row", 6, 6),
             Token(K">table", 6, 6)]
        @test collect(Lexer("| cell | two | three")) ==
            [Token(K"<table", 1, 1),
             Token(K"<table_row", 1, 1),
             Token(K"<table_cell", 3, 3),
             Token(K">table_cell", 8, 8),
             Token(K"<table_cell", 9, 9),
             Token(K">table_cell", 14, 14),
             Token(K"<table_cell", 15, 15),
             Token(K">table_cell", 20, 20),
             Token(K">table_row", 20, 20)]
        @test collect(Lexer("| a\n| b\n| c")) ==
            [Token(K"<table", 1, 1),
             Token(K"<table_row", 1, 1),
             Token(K">table_row", 3, 3),
             Token(K"<table_row", 5, 5),
             Token(K">table_row", 7, 7),
             Token(K"<table_row", 9, 9),
             Token(K">table_row", 11, 11)]
        @test collect(Lexer("|-")) ==
            [Token(K"<table", 1, 1),
             Token(K"table_row[1]", 1, 2)]
        @test collect(Lexer("| header |\n|---|\n| content |")) ==
            [Token(K"<table", 1, 1),
             Token(K"<table_row", 1, 1),
             Token(K"<table_cell", 3, 3),
             Token(K">table_cell", 10, 10),
             Token(K">table_row", 10, 10),
             Token(K"table_row[1]", 12, 16),
             Token(K"<table_row", 18, 18),
             Token(K"<table_cell", 20, 20),
             Token(K">table_cell", 28, 28),
             Token(K">table_row", 28, 28)]
    end
    @testset "Clock" begin
        @test collect(Lexer("clock: => 12:30")) ==
            [Token(K"<clock", 1, 1)]
        @test collect(Lexer("clock: [2024-10-12]")) ==
            [Token(K"<clock", 1, 1)]
        @test collect(Lexer("clock: [2019-03-25 Mon 10:49]--[2019-03-25 Mon 11:31] =>  0:42")) ==
            [Token(K"<clock", 1, 1)]
        @test collect(Lexer("clock: 12:30")) !=
            [Token(K"<clock", 1, 1)]
        @test collect(Lexer("clock: [2024-10-12]--")) !=
            [Token(K"<clock", 1, 1)]
    end
    @testset "Diary sexp" begin
       @test collect(Lexer("%%(org-calendar-holiday)")) ==
            [Token(K"diarysexp", 1, 25)]
        @test collect(Lexer("%%(org-class 2012 1 1 2013 12 12 2 \"New Year's Day\")")) ==
            [Token(K"diarysexp", 1, 53)]
        @test collect(Lexer("%%(diary-float t 4 2 \"Meeting (important)\")")) ==
            [Token(K"diarysexp", 1, 44)]
    end
    @testset "Planning" begin
        @test collect(Lexer("* Heading\nSCHEDULED: <2025-03-15 Sat>")) ==
            [Token(K"heading[1]", 1, 9),
             Token(K"planning[1]", 11, 38)]
        @test collect(Lexer("* Heading\n  SCHEDULED:  <2025-03-15 Sat>  ")) ==
            [Token(K"heading[1]", 1, 9),
             Token(K"planning[1]", 13, 41)]
        @test collect(Lexer("* Heading\nSCHEDULED: [2025-03-15 Sat]--[2025-03-16 Sun]")) ==
            [Token(K"heading[1]", 1, 9),
             Token(K"planning[1]", 11, 56)]
        @test collect(Lexer("* Heading\n SCHEDULED: <2025-03-15 Sat> DEADLINE: <2025-04-01 Tue> CLOSED: <2025-03-10 Mon>")) ==
            [Token(K"heading[1]", 1, 9),
             Token(K"planning[7]", 12, 91)]
    end
    @testset "Comments" begin
        @test collect(Lexer("#")) ==
            [Token(K"comment", 1, 1)]
        @test collect(Lexer("# comment")) ==
            [Token(K"comment", 1, 9)]
        @test collect(Lexer("# comment\n# more")) ==
            [Token(K"comment", 1, 16)]
        @test collect(Lexer("# comment\n#\n# more")) ==
            [Token(K"comment", 1, 18)]
        @test collect(Lexer("# comment\n # \n# more\n")) ==
            [Token(K"comment", 1, 20)]
    end
    @testset "Fixed width" begin
        @test collect(Lexer(":")) ==
            [Token(K"fixedwidth", 1, 1)]
        @test collect(Lexer(": fixed")) ==
            [Token(K"fixedwidth", 1, 7)]
        @test collect(Lexer(": fixed\n: more")) ==
            [Token(K"fixedwidth", 1, 14)]
        @test collect(Lexer(": fixed\n:\n: more")) ==
            [Token(K"fixedwidth", 1, 16)]
        @test collect(Lexer(": fixed\n : \n: more\n")) ==
            [Token(K"fixedwidth", 1, 18)]
    end
    @testset "Horizontal rule" begin
        @test collect(Lexer("----")) == Token[]
        @test collect(Lexer("-- ---")) == Token[]
        @test collect(Lexer("-----")) ==
            [Token(K"hrule", 1, 5)]
        @test collect(Lexer("------")) ==
            [Token(K"hrule", 1, 6)]
        @test collect(Lexer("-----   ")) ==
            [Token(K"hrule", 1, 5)]
    end
    @testset "Type inference" begin
        @testset "Utilities" begin
            bytes, pos = codeunits("abc"), UInt32(1)
            @inferred Bool   Org.iswhitespace(bytes, pos)
            @inferred Bool   Org.islongwhitespace(bytes, pos)
            @inferred Bool   Org.containswhitespace(bytes, 1, 3)
            @inferred UInt32 Org.utf8bytes(bytes, pos)
            @inferred UInt32 Org.skipplain(bytes, pos)
            @inferred Tuple{UInt32, UInt32} Org.charat(bytes, pos)
            @inferred UInt32 Org.skipwords(bytes, pos)
            @inferred UInt32 Org.skipcharsets(bytes, pos)
            @inferred Bool   Org.ischarat(bytes, pos, 'a')
            @inferred Bool   Org.islineend(bytes, pos)
            @inferred UInt32 Org.lineend(bytes, pos)
            @inferred Bool   Org.hasprefix(bytes, pos, "ab")
            @inferred UInt32 Org.countsame(bytes, pos, 'a')
            @inferred UInt32 Org.nextchar(bytes, pos, 'a')
            @inferred UInt32 Org.untilwhitespace(bytes, pos)
            @inferred Tuple{UInt32, UInt32} Org.skipnewlines(bytes, pos)
            @inferred UInt8  Org.word2tag(bytes, 1, 3)
        end
        @testset "Lexers" begin
            lstate, bytes, pos = LexerState(), codeunits("abc"), UInt32(1)
            @inferred Tuple{Token, UInt32} Org.lexnext(lstate, bytes, pos)
            @inferred Tuple{Token, UInt32} Org.lex_heading(lstate, bytes, pos)
            @inferred Tuple{Token, UInt32} Org.lex_drawer(lstate, bytes, pos)
            @inferred Tuple{Token, UInt32} Org.lex_footnotedef(lstate, bytes, pos)
            @inferred Tuple{Token, UInt32} Org.lex_item(lstate, bytes, pos, 1)
            @inferred Tuple{Token, UInt32} Org.lex_hashplus(lstate, bytes, pos)
            @inferred Tuple{Token, UInt32} Org.lex_block(lstate, bytes, pos)
            @inferred Tuple{Token, UInt32} Org.lex_dynamicblock(lstate, bytes, pos)
            @inferred Tuple{Token, UInt32} Org.lex_keyword(lstate, bytes, pos)
            @inferred Tuple{Token, UInt32} Org.lex_clock(lstate, bytes, pos)
            @inferred Tuple{Token, UInt32} Org.lex_diarysexp(lstate, bytes, pos)
            @inferred Tuple{Token, UInt32} Org.lex_planning(lstate, bytes, pos)
            @inferred Tuple{Token, UInt32} Org.lex_comment(lstate, bytes, pos)
            @inferred Tuple{Token, UInt32} Org.lex_fixedwidth(lstate, bytes, pos)
            @inferred Tuple{Token, UInt32} Org.lex_hrule(lstate, bytes, pos)
        end
    end
    @testset "Unhandled errors" begin
        @testset "Utilities" begin
            bytes, pos = codeunits("abc"), UInt32(1)
            @test_call Org.iswhitespace(bytes, pos)
            @test_call Org.islongwhitespace(bytes, pos)
            @test_call Org.containswhitespace(bytes, 1, 3)
            @test_call Org.utf8bytes(bytes, pos)
            @test_call Org.skipplain(bytes, pos)
            @test_call Org.charat(bytes, pos)
            @test_call Org.skipwords(bytes, pos)
            @test_call Org.skipcharsets(bytes, pos)
            @test_call Org.ischarat(bytes, pos, 'a')
            @test_call Org.islineend(bytes, pos)
            @test_call Org.lineend(bytes, pos)
            @test_call Org.hasprefix(bytes, pos, "ab")
            @test_call Org.countsame(bytes, pos, 'a')
            @test_call Org.nextchar(bytes, pos, 'a')
            @test_call Org.untilwhitespace(bytes, pos)
            @test_call Org.skipnewlines(bytes, pos)
            @test_call Org.word2tag(bytes, 1, 3)
        end
        @testset "Lexers" begin
            lstate, bytes, pos = LexerState(), codeunits("abc"), UInt32(1)
            @test_call Org.lexnext(lstate, bytes, pos)
            @test_call Org.lex_heading(lstate, bytes, pos)
            @test_call Org.lex_drawer(lstate, bytes, pos)
            @test_call Org.lex_footnotedef(lstate, bytes, pos)
            @test_call Org.lex_item(lstate, bytes, pos, 1)
            @test_call Org.lex_hashplus(lstate, bytes, pos)
            @test_call Org.lex_block(lstate, bytes, pos)
            @test_call Org.lex_dynamicblock(lstate, bytes, pos)
            @test_call Org.lex_keyword(lstate, bytes, pos)
            @test_call Org.lex_clock(lstate, bytes, pos)
            @test_call Org.lex_diarysexp(lstate, bytes, pos)
            @test_call Org.lex_planning(lstate, bytes, pos)
            @test_call Org.lex_comment(lstate, bytes, pos)
            @test_call Org.lex_fixedwidth(lstate, bytes, pos)
            @test_call Org.lex_hrule(lstate, bytes, pos)
        end
        @testset "Iteration" begin
            @test_call iterate(Lexer("abc"), LexerState())
        end
    end
    @testset "Type instabilities" begin
        @testset "Utilities" begin
            bytes, pos = codeunits("abc"), UInt32(1)
            @test_opt Org.iswhitespace(bytes, pos)
            @test_opt Org.islongwhitespace(bytes, pos)
            @test_opt Org.containswhitespace(bytes, 1, 3)
            @test_opt Org.utf8bytes(bytes, pos)
            @test_opt Org.skipplain(bytes, pos)
            @test_opt Org.charat(bytes, pos)
            @test_opt Org.skipwords(bytes, pos)
            @test_opt Org.skipcharsets(bytes, pos)
            @test_opt Org.ischarat(bytes, pos, 'a')
            @test_opt Org.islineend(bytes, pos)
            @test_opt Org.lineend(bytes, pos)
            @test_opt Org.hasprefix(bytes, pos, "ab")
            @test_opt Org.countsame(bytes, pos, 'a')
            @test_opt Org.nextchar(bytes, pos, 'a')
            @test_opt Org.untilwhitespace(bytes, pos)
            @test_opt Org.skipnewlines(bytes, pos)
            @test_opt Org.word2tag(bytes, 1, 3)
        end
        @testset "Lexers" begin
            lstate, bytes, pos = LexerState(), codeunits("abc"), UInt32(1)
            @test_opt Org.lexnext(lstate, bytes, pos)
            @test_opt Org.lex_heading(lstate, bytes, pos)
            @test_opt Org.lex_drawer(lstate, bytes, pos)
            @test_opt Org.lex_footnotedef(lstate, bytes, pos)
            @test_opt Org.lex_item(lstate, bytes, pos, 1)
            @test_opt Org.lex_hashplus(lstate, bytes, pos)
            @test_opt Org.lex_block(lstate, bytes, pos)
            @test_opt Org.lex_dynamicblock(lstate, bytes, pos)
            @test_opt Org.lex_keyword(lstate, bytes, pos)
            @test_opt Org.lex_clock(lstate, bytes, pos)
            @test_opt Org.lex_diarysexp(lstate, bytes, pos)
            @test_opt Org.lex_planning(lstate, bytes, pos)
            @test_opt Org.lex_comment(lstate, bytes, pos)
            @test_opt Org.lex_fixedwidth(lstate, bytes, pos)
            @test_opt Org.lex_hrule(lstate, bytes, pos)
        end
        @testset "Iteration" begin
            @test_opt iterate(Lexer("abc"), LexerState())
        end
    end
end
