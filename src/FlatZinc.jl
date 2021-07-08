module FlatZinc

export parsefile

include("utils.jl")
include("lexer.jl")
include("parser.jl")


"""
    parsefile(path)

Main entry point for package. Load file, tokenize it and
parse.
Returns head node of AST.
"""
function parsefile(path)
    tokens = open(tokenize, path);
    match(TokenStream(tokens), :model);
end

end
