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

@testset "parser!" begin
    @testset "Headline" begin
        org = OrgDocument()
        @test parser!("***", org, Headline) === nothing
        @test parser!("***hello", org, Headline) === nothing
        @test parser!("hello world", org, Headline) === nothing
        @test isempty(org)
        hl = parser!("* Basic Headline :with:tags:", org, Headline)
        @test hl.level == 1
        @test hl.tags == ["with", "tags"]
        @test hl.title == "Basic Headline"
        @test isempty(hl)
        @test isa(first(org), Headline)
        hl2 = parser!("** Basic headline without tags", org, Headline)
        @test hl2.level == 2
        @test isempty(hl2.tags)
        @test hl2.title == "Basic headline without tags"
        @test isempty(hl2)
        @test first(first(org)).title == "Basic headline without tags"
        hl3 = parser!("** Another basic headline", org, Headline)
        @test length(first(org)) == 2
        @test last(first(org)).title == "Another basic headline"
    end#@testset

    @testset "Paragraph" begin
        org = OrgDocument()
        # newline without an existing paragraph shouldn't change anything
        @test isempty(parser!("", org, Paragraph).content)
        @test isempty(org)

        p1 = parser!("Hello", org, Paragraph)
        @test length(p1) == 1
        @test last(p1) == "Hello\n"
        @test !p1.finished
        @test length(org) == 1
        @test isa(last(org), Paragraph)
        @test last(last(org)) == "Hello\n"
        # Still within same paragraph
        p2 = parser!("World", org, Paragraph)
        @test p1 === p2
        @test length(p2) == 1
        @test !p2.finished
        @test length(org) == 1
        @test last(last(org)) == "Hello\nWorld\n"
        p3 = parser!("", org, Paragraph)
        @test p1 === p3
        @test p3.finished
        @test last(last(org)) == "Hello\nWorld\n"

        # And now a second paragraph just to make sure
        p4 = parser!("Foobar foo bar", org, Paragraph)
        @test p4 !== p1
        @test !p4.finished
        @test last(p4) == "Foobar foo bar\n"
        @test length(org) == 2
        @test last(last(org)) == "Foobar foo bar\n"
    end
end#@testset
