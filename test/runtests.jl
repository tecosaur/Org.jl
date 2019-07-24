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
end#@testset
