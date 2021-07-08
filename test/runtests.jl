using Test
using AbstractTrees

using FlatZinc
using FlatZinc: TokenStream, AbstractNode, DataNode, Node, next, reset, context
using FlatZinc: match!, match_many!, match_token, match_many

include("lexert_test.jl")
include("parser_test.jl")
