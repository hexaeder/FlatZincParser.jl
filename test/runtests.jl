using FlatZinc
using Test

@testset "FlatZinc.jl" begin
    @testest "inany" begin
        using FlatZinc: inany
        @test !inany('a', 'b':'d', 'A':'Z')
        @test inany('a', 'a':'d', 'A':'Z')
        @test inany('B', 'a':'d', 'A':'Z')
    end

    @testest "read while" begin
        using FlatZinc: read_while
        iob = IOBuffer("123abc#12")
        @test read_while(iob, '1':'3', 'a':'z') == "123abc"
        @test read(iob, Char) == '#'

        iob = IOBuffer("123abc#12")
        @test read_while(iob, 'a':'z') == ""
        @test read_while(iob, '1':'3', 'a':'z', '#') == "123abc#12"
        @test eof(iob)
        iob = IOBuffer("123abc#12!")
        @test read_while(iob, '1':'3', 'a':'z', '#') == "123abc#12"
    end

    @testset "peek2" begin
        io = IOBuffer("12345")
        pos = position(io)
        @test peek(1, io) == '1'
        @test peek(2, io) == '2'
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

    @testset "tokenize files" begin
        small_file = joinpath(@__DIR__,"files", "queens3_4.fzn")
        big_file = joinpath(@__DIR__,"files", "2018_test-scheduling_t100m10r3-2.fzn")
        for file in [small_file, big_file]
            tokens = open(file) do io
                tokenize(io)
            end
            i, b, f = 0, 0, 0
            for t in tokens
                if t.type == FlatZinc.INT_LITERAL
                    parse(Int, t.lexme)
                    i += 1
                end
                if t.type == FlatZinc.BOOL_LITERAL
                    parse(Bool, t.lexme)
                    b += 1
                end
                if t.type == FlatZinc.FLOAT_LITERAL
                    parse(Float64, t.lexme)
                    f += 1
                end
            end
            println("Parsed $i integers, $b bools and $f floats correctly")
        end

        tokens = open(file) do io
            tokenize(io)
        end
        idents = filter(t -> t.type == FlatZinc.IDENTIFIER, tokens)
    end
end
