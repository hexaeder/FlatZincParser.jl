module FlatZinc

export Lexer, TokenType, Token, tokenize

@enum TokenType begin
    PARENTHESES_L
    PARENTHESES_R
    BRACKET_L
    BRACKET_R
    BRACE_L
    BRACE_R
    SEMICOLON
    COLON
    COMMA
    DOUBLECOLON
    DOTDOT
    EQUALSIGN
    NEWLINE
    KEYWORD
    BASIC_PAR_TYPE
    BOOL_LITERAL
    INT_LITERAL
    FLOAT_LITERAL
    IDENTIFIER
end

const KEYWORDS = [
    "predicate",
    "var",
    "constraint",
    "of",
    "in",
    "array",
    "solve",
    "set",
    "satisfy",
    "minimize",
    "maximize"
]

const TYPES = ["bool", "int", "float"]

struct Token
    type::TokenType
    lexme::String
end
Token(t::TokenType) = Token(t, "")

function Base.show(io::IO, t::Token)
    print(io, t.type)
    isempty(t.lexme) || print(io, " : ", t.lexme)
end

struct Lexer{IO_t <: IO}
    io::IO_t
end
Lexer(s::String) = Lexer(IOBuffer(s))

function Base.collect(lex::Lexer)
    a = Token[]
    for token in lex
        push!(a, token)
    end
    return a
end

tokenize(s) = collect(Lexer(s))

function Base.iterate(l::Lexer)
    seekstart(l.io)
    iterate(l, l.io)
end

function Base.iterate(l::Lexer, io)
    if eof(l.io)
        return nothing
    end

    # skip whitespaces
    c = read(l.io, Char)
    while c ∈ [' ', '\t']
        c = read(l.io, Char)
    end

    # check for magic charactes
    if c == '('
        return (Token(PARENTHESES_L), io)
    elseif c == ')'
        return (Token(PARENTHESES_R), io)
    elseif c == '['
        return (Token(BRACKET_L), io)
    elseif c == ']'
        return (Token(BRACKET_R), io)
    elseif c == '{'
        return (Token(BRACE_L), io)
    elseif c == '}'
        return (Token(BRACE_R), io)
    elseif c == ';'
        return (Token(SEMICOLON), io)
    elseif c == ':'
        if peek(1, io) == ':'
            skip(io, 1)
            return (Token(DOUBLECOLON), io)
        else
            return (Token(COLON), io)
        end
    elseif c == ','
        return (Token(COMMA), io)
    elseif c == '='
        return (Token(EQUALSIGN), io)
    elseif c == '\n'
        return (Token(NEWLINE), io)
    elseif c == '.'
        read_single(io, '.'; needsmatch=true)
        return (Token(DOTDOT), io)
    end

    # check for word
    if inany(c, 'a':'z', 'A':'Z')
        word = string(c)
        word *= read_while(io, 'a':'z', 'A':'Z', '0':'9', '_')

        if word ∈ KEYWORDS
            return (Token(KEYWORD, word), io)
        elseif word ∈ TYPES
            return (Token(BASIC_PAR_TYPE, word), io)
        elseif word ∈ ["true", "false"]
            return (Token(BOOL_LITERAL, word), io)
        else
            return (Token(IDENTIFIER, word), io)
        end
    end

    # number literal
    word = string(c)
    if c == '-'
        c = read(l.io, Char)
        @assert c ∈ '0':'9' "Found minus without following number!"
        word *= c
    end

    if inany(c, '0':'9')
        if c=='0' && peek(1, io) ∈ 'x' # hex literal
            word *= read(io, Char)
            word *= read_while(io, '0':'9', 'a':'f', 'A':'F'; needsmatch=true)
            return (Token(INT_LITERAL, word), io)
        elseif c=='0' && peek(1, io) ∈ 'o' #?? literal
            word *= read(io, Char)
            word *= read_while(io, '0':'7'; needsmatch=true)
            peek(1, io) ∉ '8':'9' || error("oh boy that doesnt fit the oct literal")
            return (Token(INT_LITERAL, word), io)
        else
            word *= read_while(io, '0':'9') # read rest of number
            if peek(1, io) ∈ ('.', 'e', 'E') && inany(peek(2, io), '0':'9', '+', '-')# ouuhh it's a float
                word *= read_single(io, '.')
                word *= read_while(io, '0':'9', needsmatch=true)
                word *= read_single(io, ('e','E'))
                if word[end] ∈ ('e','E')
                    word *= read_single(io, ('+','-'))
                    word *= read_while(io, '0':'9')
                end
                return (Token(FLOAT_LITERAL, word), io)
            else # this is an iteger!
                return (Token(INT_LITERAL, word), io)
            end
        end #
    end

    error("No token found: ", context(io))
end

function read_while(io, collections...; needsmatch=false)
    str = ""
    try
        c = read(io, Char)
        while inany(c, collections...)
            str *= c
            c = read(io, Char)
        end
        skip(io, -1) # go one back
    catch e
        e isa EOFError || rethrow(e)
    end
    needsmatch && isempty(str) && error("Nothing matches $collections here: $(context(io))")
    return str
end

function read_single(io, collections...; needsmatch=false)
    eof(io) && !needsmatch && return ""
    c = read(io, Char)
    if inany(c, collections...)
        return string(c)
    else
        skip(io, -1)
        needsmatch && error("Nothing matches $collections here: $(context(io))")
        return ""
    end
end

function inany(e, collections...)
    for c in collections
        e ∈ c && return true
    end
    return false
end

function peek(i::Int, io, T=Char)
    pos = position(io)
    skip(io, i-1)
    r = read(io, T)
    seek(io, pos)
    return r
end

function context(io; before=10, after=10)
    pos = position(io)
    skip(io, -before)
    str = ""
    for i in 1:(before+after)
        str *= read(io, Char)
    end
    seek(io, pos)
    return str
end

end
