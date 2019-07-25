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

using Test, Org

nc = Org.nocontext

@testset "parser!" begin
    @testset "Headline" begin
        org = Document()
        @test parser!("***", org, Headline, nc) === nothing
        @test parser!("***hello", org, Headline, nc) === nothing
        @test parser!("hello world", org, Headline, nc) === nothing
        @test isempty(org)
        hl = parser!("* Basic Headline :with:tags:", org, Headline, nc)
        @test hl.level == 1
        @test hl.tags == ["with", "tags"]
        @test hl.title == "Basic Headline"
        @test isempty(hl)
        @test isa(first(org), Headline)
        hl2 = parser!("** Basic headline without tags", org, Headline, nc)
        @test hl2.level == 2
        @test isempty(hl2.tags)
        @test hl2.title == "Basic headline without tags"
        @test isempty(hl2)
        @test first(first(org)).title == "Basic headline without tags"
        hl3 = parser!("** Another basic headline", org, Headline, nc)
        @test length(first(org)) == 2
        @test last(first(org)).title == "Another basic headline"
    end#@testset

    @testset "Paragraph" begin
        org = Document()
        # newline without an existing paragraph shouldn't change anything
        p0 = parser!("", org, Paragraph, nc)
        @test p0 === nc
        @test isempty(org)

        p1 = parser!("Hello", org, Paragraph, nc)
        @test length(p1) == 1
        @test last(p1) == "Hello\n"
        @test length(org) == 1
        @test isa(last(org), Paragraph)
        @test last(last(org)) == "Hello\n"
        # Still within same paragraph
        p2 = parser!("World", org, Paragraph, p1)
        @test p1 === p2
        @test length(p2) == 2
        @test length(org) == 1
        @test last(last(org)) == "World\n"
        p3 = parser!("", org, Paragraph, p1)
        @test p3 === nc
        @test last(org).content == ["Hello\n", "World\n"]

        # And now a second paragraph just to make sure
        p4 = parser!("Foobar foo bar", org, Paragraph, nc)
        @test p4 !== p1
        @test last(p4) == "Foobar foo bar\n"
        @test length(org) == 2
        @test last(org).content == ["Foobar foo bar\n"]
        @test first(org).content == ["Hello\n", "World\n"]
    end
end#@testset

@testset "parse" begin
    doc = """
* Hello :my:tags:
This is a paragraph.
* Foobar
foo bar.
**** Barfoo
bar foo.
** Goodbye    :goodbyetag:
This is the end of the document.
    """
    org = parse_org(doc)
    @test length(org) == 2
    @test first(org).title == "Hello"
    @test first(org).tags == ["my", "tags"]
    @test length(org[1]) == 1
    @test org[1][1].content == ["This is a paragraph.\n"]
    @test org[2].title == "Foobar"
    @test org[2][1].content == ["foo bar.\n"]
    @test org[2][2].title == "Barfoo"
    @test level(org[2][2]) == 4
    @test length(org[2]) == 3
    @test org[2][3].title == "Goodbye"
    @test level(org[2][3]) == 2
    @test org[2][3].tags == ["goodbyetag"]
end#@testset
