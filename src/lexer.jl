export Lexer, tokenize

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
    if eof(io)
        return nothing
    end

    # skip whitespaces
    c = readchar(io)
    while c ∈ [' ', '\t']
        c = readchar(io)
    end

    # check for magic charactes
    if c == '('
        return (Token(:parentheses_l), io)
    elseif c == ')'
        return (Token(:parentheses_r), io)
    elseif c == '['
        return (Token(:bracket_l), io)
    elseif c == ']'
        return (Token(:bracket_r), io)
    elseif c == '{'
        return (Token(:brace_l), io)
    elseif c == '}'
        return (Token(:brace_r), io)
    elseif c == ';'
        return (Token(:semicolon), io)
    elseif c == ':'
        if peek1(io) == ':'
            skip(io, 1)
            return (Token(:doublecolon), io)
        else
            return (Token(:colon), io)
        end
    elseif c == ','
        return (Token(:comma), io)
    elseif c == '='
        return (Token(:equalsign), io)
    elseif c == '\n'
        return (Token(:newline), io)
    elseif c == '.'
        read_single(io, '.'; needsmatch=true)
        return (Token(:dotdot), io)
    end

    # check for word
    if inany(c, 'a':'z', 'A':'Z')
        word = string(c)
        word *= read_while(io, 'a':'z', 'A':'Z', '0':'9', '_')

        if word ∈ KEYWORDS
            return (Token(:keyword, word), io)
        elseif word ∈ TYPES
            return (Token(:basic_par_type, word), io)
        elseif word ∈ ["true", "false"]
            return (Token(:bool_literal, word), io)
        else
            return (Token(:identifier, word), io)
        end
    end

    # number literal
    word = string(c)
    if c == '-'
        c = readchar(io)
        @assert c ∈ '0':'9' "Found minus without following number!"
        word *= c
    end

    if inany(c, '0':'9')
        if c=='0' && peek1(io) ∈ 'x' # hex literal
            word *= readchar(io)
            word *= read_while(io, '0':'9', 'a':'f', 'A':'F'; needsmatch=true)
            return (Token(:int_literal, word), io)
        elseif c=='0' && peek1(io) ∈ 'o' #?? literal
            word *= readchar(io)
            word *= read_while(io, '0':'7'; needsmatch=true)
            peek1(io) ∉ '8':'9' || error("oh boy that doesnt fit the oct literal")
            return (Token(:int_literal, word), io)
        else
            word *= read_while(io, '0':'9') # read rest of number
            if peek1(io) ∈ ('.', 'e', 'E') && inany(peek2(io), '0':'9', '+', '-')# ouuhh it's a float
                word *= read_single(io, '.')
                word *= read_while(io, '0':'9')
                word *= read_single(io, ('e','E'))
                if word[end] ∈ ('e','E')
                    word *= read_single(io, ('+','-'))
                    word *= read_while(io, '0':'9')
                end
                return (Token(:float_literal, word), io)
            else # this is an iteger!
                return (Token(:int_literal, word), io)
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

function peekn(i::Int, io, T=Char)
    pos = position(io)
    skip(io, i-1)
    r = read(io, T)
    seek(io, pos)
    return r
end
peek1(io) = peekn(1, io)
peek2(io) = peekn(2, io)

function readchar(io, ifeof=nothing)
    eof(io) && return ifeof
    return read(io, Char)
end

function context(io; before=10, after=10)
    pos = position(io)
    skip(io, -before)
    str = ""
    for i in 1:before
        str *= readchar(io, "EOF")
    end
    str *= "^" * readchar(io, "EOF") * "^"
    for i in 1:after
        str *= readchar(io, "EOF")
    end
    seek(io, pos)
    return str
end
