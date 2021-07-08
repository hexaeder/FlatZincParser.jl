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
    _cache = IOBuffer(; sizehint=100)
    iterate(l, (l.io, _cache))
end

function Base.iterate(l::Lexer, state)
    io, _cache = state
    if eof(io)
        return nothing
    end

    # skip whitespaces
    c = readchar(io)
    while c ∈ (' ', '\t')
        c = readchar(io)
    end

    # check for magic charactes
    if c == '('
        return (Token(:parentheses_l), state)
    elseif c == ')'
        return (Token(:parentheses_r), state)
    elseif c == '['
        return (Token(:bracket_l), state)
    elseif c == ']'
        return (Token(:bracket_r), state)
    elseif c == '{'
        return (Token(:brace_l), state)
    elseif c == '}'
        return (Token(:brace_r), state)
    elseif c == ';'
        return (Token(:semicolon), state)
    elseif c == ':'
        if peek1(io) == ':'
            skip(io, 1)
            return (Token(:doublecolon), state)
        else
            return (Token(:colon), state)
        end
    elseif c == ','
        return (Token(:comma), state)
    elseif c == '='
        return (Token(:equalsign), state)
    elseif c == '\n'
        return (Token(:newline), state)
    elseif c == '.'
        read_single(io, '.'; needsmatch=true)
        return (Token(:dotdot), state)
    end

    # check for word
    if inany(c, 'a':'z', 'A':'Z', '_') # XXX: i allow _ as begin for all identifiers
        write(_cache, c)
        read_while!(_cache, io, 'a':'z', 'A':'Z', '0':'9', '_')
        word = String(take!(_cache))
        if word ∈ KEYWORDS
            return (Token(:keyword, word), state)
        elseif word ∈ TYPES
            return (Token(:basic_par_type, word), state)
        elseif word ∈ ["true", "false"]
            return (Token(:bool_literal, word), state)
        else
            return (Token(:identifier, word), state)
        end
    end

    # number literal
    write(_cache, c) # start cache with single char
    if c == '-'
        c = readchar(io)
        @assert c ∈ '0':'9' "Found minus without following number!"
        write(_cache, c)
    end

    if inany(c, '0':'9')
        if c=='0' && peek1(io) ∈ 'x' # hex literal
            write(_cache, readchar(io)) # write the peeked x
            read_while!(_cache, io, '0':'9', 'a':'f', 'A':'F'; needsmatch=true)
            word = String(take!(_cache))
            return (Token(:int_literal, word), state)
        elseif c=='0' && peek1(io) ∈ 'o' #?? literal
            write(_cache, readchar(io)) # write the peeked o
            read_while!(_cache, io, '0':'7'; needsmatch=true)
            peek1(io) ∉ '8':'9' || error("oh boy that doesnt fit the oct literal")
            word = String(take!(_cache))
            return (Token(:int_literal, word), state)
        else
            read_while!(_cache, io, '0':'9') # read rest of number
            if peek1(io) ∈ ('.', 'e', 'E') && inany(peek2(io), '0':'9', '+', '-')# ouuhh it's a float
                read_single!(_cache, io, '.')
                read_while!(_cache, io, '0':'9')
                found_e = read_single!(_cache, io, ('e','E'))
                if found_e
                    read_single!(_cache, io, ('+','-'))
                    read_while!(_cache, io, '0':'9')
                end
                word = String(take!(_cache))
                return (Token(:float_literal, word), state)
            else # this is an iteger!
                word = String(take!(_cache))
                return (Token(:int_literal, word), state)
            end
        end #
    end

    error("No token found: ", context(io))
end

function read_while!(_target, io, collections...; needsmatch=false)
    i = 0
    c = readchar(io)
    # XXX: the sluped collections lead to allocations for more than one match
    while inany(c, collections...)
        write(_target, c)
        i += 1
        c = readchar(io)
    end
    c===nothing || skip(io, -1) # go one back unless eof was reached

    needsmatch && i==0 && error("Nothing matches $collections here: $(context(io))")
    return i
end

function read_while(args...; kwargs...)
    _target = IOBuffer()
    read_while!(_target, args...; kwargs...)
    return String(take!(_target))
end

function read_single!(_target, io, collections...; needsmatch=false)
    c = readchar(io)
    if inany(c, collections...)
        write(_target, c)
        return true
    else
        c===nothing || skip(io, -1) # go one back unless eof was reached
        needsmatch && error("Nothing matches $collections here: $(context(io))")
        return false
    end
end

function read_single(args...; kwargs...)
    _target = IOBuffer(sizehint=1)
    read_while!(_target, args...; kwargs...)
    return String(take!(_target))
end

function inany(e, collections...)
    for c in collections
        e ∈ c && return true
    end
    return false
end

function peekn(i::Int, io)
    pos = position(io)
    skip(io, i-1)
    r = readchar(io)
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
