module FlatZincParser

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
function parsefile(path; async=true, spawn=true)
    if async
        token = Channel{Token}(Inf; spawn) do chnl
            io = open(path)
            try
                for token in Lexer(io)
                    put!(chnl, token)
                end
            finally
                close(io)
            end
        end
    else
        token = open(tokenize, path);
    end
    match(TokenStream(token), :model);
end

end
