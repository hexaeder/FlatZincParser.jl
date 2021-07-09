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

Base.isapprox(t1::Token, t2::Token) = t1.type == t2.type && t1.lexme == t2.lexme

function Base.show(io::IO, t::Token)
    print(io, t.type)
    isempty(t.lexme) || print(io, "\"", t.lexme, "\"")
    # iszero(t.line) || print(io, " (#", t.line, ")")
end

"""
   struct TokenStream

Holds a stream of tokens (Vector of Channel) together with
a position information.
"""
mutable struct TokenStream{T<:Union{Channel{Token}, Vector{Token}}}
    data::T
    pos::Int
    TokenStream(data) = new{typeof(data)}(data, 0)
end

TokenStream(s::String) = TokenStream(tokenize(s))

function Base.getindex(ts::TokenStream{<:Channel}, idx)
    c = ts.data
    lock(c) # aquire `cond_take` lock, i.e. nobody is allowed to take
    try
        if idx <= length(c.data)
            return c.data[idx]
        end
        # if there arn't enough elements yet just wait
        while isopen(c) && idx > length(c.data)
            wait(c.cond_take) # cond_take gets notified on every put
        end

        return c.data[idx] # finally return the data
    finally
        unlock(c)
    end
end

Base.getindex(ts::TokenStream{<:Vector}, idx) = ts.data[idx]

Base.position(ts::TokenStream) = ts.pos

function setposition!(ts::TokenStream, pos)
    ts.pos = pos
    return ts
end

reset!(ts::TokenStream) = setposition!(ts, 0)

"""
    next!(ts::TokenStream)

Get the next! element in TokenStream (increases position by one)
"""
function next!(ts::TokenStream)
    try
        token = ts[ts.pos + 1]
        ts.pos += 1
        return token
    catch e
        e isa BoundsError && return nothing
        rethrow()
    end
end

"""
    peek(ts::TokenStream)

Get the next element in TokenStream (without advancing position)
"""
function peek(ts::TokenStream)
    try
        token = ts[ts.pos + 1]
        return token
    catch e
        e isa BoundsError && return nothing
        rethrow()
    end
end

"""
    context(ts::TokenStream; before=2, after=5)

Strigify the current state of a TokenStream. Mainly
for debugging and errors.
"""
function context(ts::TokenStream; pos=position(ts), before=3, after=5)
    str = ""
    for i in (pos-before):(pos-1)
        if i == pos
            str *= " 🔥"
        end
        try
            str *= " " * string(ts[i])
        catch err
            err isa BoundsError || rethrow()
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

ParsingError(msg::String, stream::TokenStream) = ParsingError(msg, stream, position(stream)+1)

function Base.show(io::IO, err::ParsingError)
    print(io, "ParsingError: ", err.msg)
    t = err.stream[err.streampos]
    t===nothing || print(io, " around line #", t.line)
    print(io, "\n", context(err.stream, pos=err.streampos))
end
