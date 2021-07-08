export Token

struct Token
    type::Symbol
    lexme::String
end

Token(s::Symbol) = Token(s, "")
Token(s::Symbol, ::Nothing) = Token(s, "")

function Base.show(io::IO, t::Token)
    print(io, t.type)
    isempty(t.lexme) || print(io, " : ", t.lexme)
end
