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
function parsefile(path; async=false, spawn=true, parallel=true)
    if parallel && Threads.nthreads() > 1
        return parallelparse(path)
    end

    if parallel && Threads.nthreads() == 1
        @warn "This Julia instance only has on thread. Bummer. Run singlethreaded."
    end

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

    return match(TokenStream(token), :model);
end

function parallelparse(path)
    # each line as a token stream
    lines = Channel{Tuple{Int, TokenStream{Vector{Token}}}}(Inf) do chnl
        io = open(path) # load file
        try
            state = :newline
            buffer = Token[]
            ln = 1
            for token in Lexer(io)
                if state == :newline
                    ln = token.line
                    state == :inline
                elseif token.line !== ln
                    @warn "Line number $(token.line) of token does not match expectation $(ln). Each line has to end with a semicolon. Semicolons are only allowed at the end of the line!"
                end
                # write the token to the buffer
                push!(buffer, token)
                # if EOL reached put the ln and token steam to channel
                if token.type === :semicolon
                    tokens = copy(buffer)
                    empty!(buffer)
                    put!(chnl, (ln, TokenStream(tokens)))
                    state = :newline
                end
            end
        finally
            close(io)
        end
    end

    # channel for parsed nodes
    nodes = Channel{Tuple{Int, Node}}(Inf)

    # no try to parse each of the lines
    Threads.foreach(lines) do (ln, ts)
        # parse the node...
        node = match(ts, :fullline)
        # ... and put it in the nodes channel
        put!(nodes, (ln, node))
    end
    close(nodes) # close the channel

    # postprocessing, create head node and attach children in right order
    head = Node(:model)
    head.children = Vector{Node}(undef, length(nodes.data))

    for (ln, node) in nodes
        @assert type(node) === :fullline
        @assert length(node.children) == 1
        head.children[ln] = node.children[1]
    end
    # XXX: it is not checked, whether the commands are in the right order
    # so if you implement a second pass this could be checked

    return head
end

end
