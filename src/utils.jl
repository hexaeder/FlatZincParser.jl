export Token
export ParsingError

"""
    struct Token

Holds type, lexme and linenumber
"""
struct Token
    type::Symbol
    lexme::String
    line::Int
end

Token(s::Symbol, lexme="", ln=0) = Token(s, lexme, ln)
Token(s::Symbol, ln::Int) = Token(s, "", ln)
Token(s::Symbol, ::Nothing) = Token(s, "", 0)

function Base.show(io::IO, t::Token)
    print(io, t.type)
    isempty(t.lexme) || print(io, "\"", t.lexme, "\"")
    # iszero(t.line) || print(io, " (#", t.line, ")")
end

"""
   struct TokenStream

Holds a stream of tokens (vector of token + position)
Allows for next, peek, restet...
"""
mutable struct TokenStream
    token::Vector{Token}
    idx::Int
    TokenStream(token::Vector{Token}) = new(token, 0)
    TokenStream(io) = new(tokenize(io), 0)
end

function Base.getindex(tc::TokenStream, i)
    if checkbounds(Bool, tc.token, i)
        return tc.token[i]
    else
        return nothing
    end
end

function next(tc::TokenStream)
    tc.idx += 1
    tc[tc.idx]
end

Base.peek(tc::TokenStream) = tc[tc.idx + 1]

function reset(tc::TokenStream)
    tc.idx = 0
    return tc
end

"""
    context(ts::TokenStream; before=2, after=5)

Strigify the current state of a TokenStream. Mainly
for debuggin and errors.
"""
function context(ts::TokenStream; before=2, after=5, pos=ts.idx)
    str = ""
    for i in (pos-before):(pos+after)
        t = ts[i]
        if i == pos
            str *= " 🔥"
        end
        if t !== nothing
            str *= " "*string(t.type)
            if !isempty(t.lexme)
                str *= "("*t.lexme*")"
            end
        end
    end
    return str
end

"""
    ParsingError <: Exception
"""
struct ParsingError <: Exception
    msg::String
    stream::TokenStream
    streampos::Int
end

ParsingError(msg::String, stream::TokenStream) = ParsingError(msg, stream, stream.idx)

function Base.show(io::IO, err::ParsingError)
    print(io, "ParsingError: ", err.msg)
    t = err.stream[err.streampos]
    t===nothing || print(io, " around line #", t.line)
    print(io, "\n", context(err.stream, pos=err.streampos))
end
