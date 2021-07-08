using FlatZinc
using Test
using FlatZinc: TokenStream, AbstractNode, DataNode, Node, next, reset, context
using FlatZinc: match!, match_many!, match_token, match_many
using AbstractTrees

@testset "FlatZinc.jl" begin
    @testset "inany" begin
        using FlatZinc: inany
        @test !inany('a', 'b':'d', 'A':'Z')
        @test inany('a', 'a':'d', 'A':'Z')
        @test inany('B', 'a':'d', 'A':'Z')
    end

    @testset "read while" begin
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
        using FlatZinc: peekn
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

    @testset "tokenize files" begin
        small_file = joinpath(@__DIR__,"files", "queens3_4.fzn")
        big_file = joinpath(@__DIR__,"files", "2018_test-scheduling_t100m10r3-2.fzn")
        huge_file = joinpath(@__DIR__,"files", "oocsp_racks_030_f7.fzn")
        for file in [small_file, big_file, huge_file]
            @time tokens = open(file) do io
                tokenize(io)
            end
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

        #=
        string = open(big_file) do io
            read(io, String)
        end;
        @benchmark tokenize($string)


        @benchmark begin
            FlatZinc.read_while!(_target, io, '1':'9')
        end setup = begin
            _target = IOBuffer()
            io = IOBuffer("123asdb")
        end

        @benchmark begin
            FlatZinc.read_while!(_target, io, 'a':'z', '1':'9')
        end setup = begin
            _target = IOBuffer()
            io = IOBuffer("123asdb")
        end

        @benchmark begin
            FlatZinc.read_single!(_target, io, '1':'9')
        end setup = begin
            _target = IOBuffer()
            io = IOBuffer("123asdb")
        end

        @benchmark begin
            FlatZinc.read_single!(_target, io, '1':'9', 'a':'z')
        end setup = begin
            _target = IOBuffer()
            io = IOBuffer("123asdb")
        end
        =#
    end

    string = """
    var 1..4: X_INTRODUCED_0_;
    var 1..4: X_INTRODUCED_1_;
    var 1..4: X_INTRODUCED_2_;
    var 1..4: X_INTRODUCED_3_;
    array [1..4] of var int: queens:: output_array([1..4]) = [X_INTRODUCED_0_,X_INTRODUCED_1_,X_INTRODUCED_2_,X_INTRODUCED_3_];
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_0_,X_INTRODUCED_1_],0);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_0_,X_INTRODUCED_2_],0);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_0_,X_INTRODUCED_3_],0);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_1_,X_INTRODUCED_2_],0);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_1_,X_INTRODUCED_3_],0);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_2_,X_INTRODUCED_3_],0);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_0_,X_INTRODUCED_1_],1);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_0_,X_INTRODUCED_1_],-1);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_0_,X_INTRODUCED_2_],2);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_0_,X_INTRODUCED_2_],-2);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_0_,X_INTRODUCED_3_],3);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_0_,X_INTRODUCED_3_],-3);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_1_,X_INTRODUCED_2_],1);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_1_,X_INTRODUCED_2_],-1);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_1_,X_INTRODUCED_3_],2);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_1_,X_INTRODUCED_3_],-2);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_2_,X_INTRODUCED_3_],1);
    constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_2_,X_INTRODUCED_3_],-1);
    solve :: int_search(queens,first_fail,indomain_min,complete) satisfy;
    """


    @testset "match matchmany" begin
        ts = TokenStream(tokenize("1.2 2.6 0.2 ;"))
        childs = AbstractNode[]
        match!(childs, ts, :float_literal)
        match!(childs, ts, :float_literal)
        match!(childs, ts, :float_literal)
        @test_throws ParsingError match!(childs, ts, :float_literal)
        peek(ts).type === :semicolon

        ts = TokenStream(tokenize("1.2 2.6 0.2 ;"))
        @test match_many!(childs, ts, :float_literal) == 3
        peek(ts).type === :semicolon

        ts = TokenStream(tokenize("1.2, 2.6, 0.2 ;"))
        match_many(ts, :float_literal; delimiter=:comma)
    end

    @testest "matchtoken" begin
        ts = TokenStream("predicate foo bar;")
        match_token(ts, :keyword, "predicate")
        match_token(ts, :identifier, "foo")
        @test_throws ParsingError match_token(ts, :identifier, "foo")
        match_token(ts, :identifier)
        match_token(ts, :semicolon)
    end

    @testset "predicate_item" begin
        ts = TokenStream("predicate cumulativeChoco (array [int] of var int: s, array [int] of var int: d,array [int] of var int: r,var int: b);")
        match(ts, :predicate_item)
    end

    @testset "range and set literal" begin
        ts = TokenStream("1..2;")
        print_tree(match(ts, :set_literal))
        ts = TokenStream("1.2..2.5;")
        print_tree(match(ts, :set_literal))
        ts = TokenStream("{1.2,2.5,};")
        print_tree(match(ts, :set_literal))
        ts = TokenStream("{1,2,3,4,5,6,7};")
        print_tree(match(ts, :set_literal))
    end

    @testset "par_decl_item" begin
        streams = [
            TokenStream("array [1..100] of int: duration = [88,740,752,503,536,537,300,668,332,693,30,249,673,391,51,386,328,313,103,190,741,800,425,552,749,31,632,690,530,706,131,377,505,656,654,720,757,90,331,450,103,276,571,782,568,772,106,198,183,800,705,140,107,542,597,97,580,59,325,336,76,482,776,428,237,433,701,220,478,102,32,617,454,360,541,107,609,730,107,274,589,305,249,96,365,651,163,202,560,571,104,740,720,437,230,157,145,318,531,481];"),
            TokenStream("array [1..2] of int: X_INTRODUCED_1952_ = [1,-1];"),
        ]
        match(reset(streams[1]), :par_decl_item)
        match(reset(streams[2]), :par_decl_item)
    end

    @testset "array literal" begin
        str = "[X_INTRODUCED_0_,X_INTRODUCED_1_,X_INTRODUCED_2_,X_INTRODUCED_3_]"
        match(TokenStream(str), :array_literal)
        match(TokenStream("[1..4]"), :expr)
        match(TokenStream("[1..4]"), :array_literal)
        match(TokenStream("1..4"), :basic_literal_expr)
    end

    @testset "var_decl_item" begin
        streams = [
            TokenStream("var 1..4: X_INTRODUCED_0_;"),
            TokenStream("array [1..4] of var int: queens:: output_array([1..4]) = [X_INTRODUCED_0_,X_INTRODUCED_1_,X_INTRODUCED_2_,X_INTRODUCED_3_];"),
        ]
        match(reset(streams[1]), :var_decl_item)
        match(reset(streams[2]), :var_decl_item)
    end

    @testset "constraint_item" begin
        stream = TokenStream("constraint int_lin_ne(X_INTRODUCED_4_,[X_INTRODUCED_0_,X_INTRODUCED_1_],-1);")
        match(reset(stream), :constraint_item) |> print_tree

        str = "X_INTRODUCED_4_,[X_INTRODUCED_0_,X_INTRODUCED_1_],-1"
        stream = TokenStream(str)
        match(stream, :expr) |> print_tree
        match_token(stream, :comma)
        match(stream, :expr) |> print_tree
        match_token(stream, :comma)
        match(stream, :expr) |> print_tree
    end
end
