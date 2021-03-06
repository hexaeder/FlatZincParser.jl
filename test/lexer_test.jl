using Test
using AbstractTrees

using FlatZincParser
using FlatZincParser: TokenStream, AbstractNode, DataNode, Node, next!, reset!, context
using FlatZincParser: match!, match_many!, match_token, match_many

@testset "lexer" begin
    @testset "inany" begin
        using FlatZincParser: inany
        @test !inany('a', 'b':'d', 'A':'Z')
        @test inany('a', 'a':'d', 'A':'Z')
        @test inany('B', 'a':'d', 'A':'Z')
    end

    @testset "read while" begin
        using FlatZincParser: read_while, innone
        iob = IOBuffer("123abc#12")
        @test read_while(iob, ('1':'3', 'a':'z')) == "123abc"
        @test read(iob, Char) == '#'

        iob = IOBuffer("123abc#12")
        @test read_while(iob, 'a':'z') == ""
        @test read_while(iob, ('1':'3', 'a':'z', '#')) == "123abc#12"
        @test eof(iob)
        iob = IOBuffer("123abc#12!")
        @test read_while(iob, ('1':'3', 'a':'z', '#')) == "123abc#12"

        iob = IOBuffer("123a\"bc#12")
        @test read_while(iob, '"'; condition=innone) == "123a"
        @test read(iob, Char) == '\"'
    end

    @testset "peek2" begin
        using FlatZincParser: peekn
        io = IOBuffer("12345")
        pos = position(io)
        @test peekn(1, io) == '1'
        @test peekn(2, io) == '2'
        @test position(io) == pos
    end

    @testset "integer parsing" begin
        tok = tokenize("0x23fA -0o123456 9 -15;")
        @test tok[1].lexme == "0x23fA"
        @test tok[2].lexme == "-0o123456"
        @test tok[3].lexme == "9"
        @test tok[4].lexme == "-15"
    end

    @testset "float parsing" begin
        tok = tokenize("1.0 -2.3 -1e-15 8e12 -1.23E+4;")
        @test tok[1].lexme == "1.0"
        @test tok[2].lexme == "-2.3"
        @test tok[3].lexme == "-1e-15"
        @test tok[4].lexme == "8e12"
        @test tok[5].lexme == "-1.23E+4"
    end

    @testset "string literal parsing" begin
        tok = tokenize("1.0 \"\"\"this is my string\"\"\" -1e-15 8e12 -1.23E+4;")
        @test tok[2].type === :string_literal
        @test tok[2].lexme == "this is my string"
    end

    @testset "eol parsing" begin
        ts = tokenize("1.2 2.6 0.2 ;")
        @test length(ts) == 4
    end

    @testset "tokenize files" begin
        small_file = joinpath(@__DIR__,"files", "queens3_4.fzn")
        big_file = joinpath(@__DIR__,"files", "2018_test-scheduling_t100m10r3-2.fzn")
        # huge_file = joinpath(@__DIR__,"files", "oocsp_racks_030_f7.fzn")
        for file in [small_file, big_file]
            @time tokens = open(tokenize, file)
            i, b, f = 0, 0, 0
            for t in tokens
                if t.type === :int_literal
                    parse(Int, t.lexme)
                    i += 1
                end
                if t.type === :bool_literal
                    parse(Bool, t.lexme)
                    b += 1
                end
                if t.type === :float_literal
                    parse(Float64, t.lexme)
                    f += 1
                end
            end
            println("Parsed $i integers, $b bools and $f floats")
        end
    end

    # using BenchmarkTools
    # big_file = joinpath(@__DIR__,"files", "2018_test-scheduling_t100m10r3-2.fzn")
    # string = open(big_file) do io
    #     read(io, String)
    # end;
    # @btime tokenize($string)
    # 23.758 ms (239903 allocations: 17.54 MiB)
end
