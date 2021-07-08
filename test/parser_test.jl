using Test
using AbstractTrees

using FlatZinc
using FlatZinc: TokenStream, AbstractNode, DataNode, Node, next, reset, context
using FlatZinc: match!, match_many!, match_token, match_many

@testset "parser testes" begin
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

    @testset "solver_item" begin
        streams = [TokenStream("solve :: seq_search([int_search(X_INTRODUCED_2947_,first_fail,indomain_min,complete),int_search(X_INTRODUCED_2946_,input_order,indomain_min,complete)]) minimize objective;"),
                   TokenStream("solve :: seq_search(int_search(X_INTRODUCED_2947_,first_fail,indomain_min,complete),int_search(X_INTRODUCED_2946_,input_order,indomain_min,complete)) minimize objective;"),
                   TokenStream("solve :: int_search(queens,first_fail,indomain_min,complete) satisfy;"),
                   TokenStream("solve :: int_search(X_INTRODUCED_51094_,input_order,indomain_min,complete) satisfy;")]

        match(reset(streams[1]), :solve_item)
        match(reset(streams[2]), :solve_item)
        match(reset(streams[3]), :solve_item)
        match(reset(streams[4]), :solve_item)

        # try 1
        stream = reset(streams[1])
        match_token(stream, :keyword, "solve")
        match(stream, :annotations, needsmatch=true) #technically nm=true

        stream = TokenStream("[int_search(X_INTRODUCED_2947_,first_fail,indomain_min,complete),int_search(X_INTRODUCED_2946_,input_order,indomain_min,complete)]")
        match(reset(stream), :ann_expr)
        match(reset(stream), :annotation)

        match(reset(stream), :array_literal)

        # try 2
        stream = reset(streams[2])
        match_token(stream, :keyword, "solve")
        match(stream, :annotations, needsmatch=true) #technically nm=true
        stream = TokenStream("int_search(X_INTRODUCED_2947_,first_fail,indomain_min,complete),int_search(X_INTRODUCED_2946_,input_order,indomain_min,complete)")
        match(reset(stream), :expr) |> print_tree
        match(reset(stream), :annotation) |> prent_tree

    end
end
