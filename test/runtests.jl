using Test
using AbstractTrees

using FlatZincParser
using FlatZincParser: TokenStream, AbstractNode, DataNode, Node, next, reset, context
using FlatZincParser: match!, match_many!, match_token, match_many

include("lexer_test.jl")
include("parser_test.jl")
