using AbstractTrees

export ParsingError

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

function context(ts::TokenStream; before=2, after=5)
    str = ""
    for i in (ts.idx-before):(ts.idx+after)
        t = ts[i]
        if i == ts.idx
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

abstract type AbstractNode end


struct DataNode{D} <: AbstractNode
    data::D
end

AbstractTrees.printnode(io::IO, node::DataNode) = print(io, node.data)


mutable struct Node{T} <: AbstractNode
    children::Vector{AbstractNode}
    Node(type) = new{type}(AbstractNode[])
end

type(::Node{T}) where {T} = T

AbstractTrees.children(node::Node) = node.children

AbstractTrees.printnode(io::IO, node::Node) = print(io, type(node))

struct ParsingError <: Exception
    msg::String
    stream::TokenStream
end
function Base.show(io::IO, err::ParsingError)
    print(io, "ParsingError: ", err.msg, " around\n", context(err.stream))
end


function Base.match(stream::TokenStream, type::Symbol;  kwargs...)
    children = AbstractNode[]
    match!(children, stream, type; kwargs...)
end

function match!(children, stream::TokenStream, type::Symbol; needsmatch=true)
    candidate = Node(type)
    idx = stream.idx
    try
        construct(candidate, stream)
        push!(children, candidate)
        return candidate
    catch err
        if err isa ParsingError && !needsmatch
            stream.idx = idx # reset stream position
        else
            rethrow()
        end
    end
    return nothing
end

function match_many(args...; kwargs...)
    children = AbstractNode[]
    match_many!(children, args...; kwargs...)
    return children
end

function match_many!(children, stream, type; needsmatch=true, delimiter=nothing)
    counter = 0
    while true
        # try to match type, if its the first one check needsmatch
        found = match!(children, stream, type;
                       needsmatch = (needsmatch && iszero(counter)))
        found === nothing && break # break if no match
        counter += 1

        if delimiter !== nothing
            delim = match_token(stream, delimiter, needsmatch=false)
            # XXX is this right? break scan if no delim found
            delim === nothing && break
        end
    end
    return counter
end

function match_token(stream::TokenStream, type::Symbol, lexme=nothing; needsmatch=true)
    t = peek(stream)

    if t!==nothing && type === t.type && (lexme === nothing  || string(lexme) == t.lexme)
        return next(stream)
    else
        if needsmatch
            throw(ParsingError("Wrong token! got '$t' but requested '$(Token(type, lexme))'", stream))
        end
        return nothing
    end
end

function construct(n::Node{:bool_literal}, stream)
    t = match_token(stream, :bool_literal)
    d = DataNode(parse(Bool, t.lexme))
    n.children = [d]
end

function construct(n::Node{:int_literal}, stream)
    t = match_token(stream, :int_literal)
    d = DataNode(parse(Int, t.lexme))
    n.children = [d]
end

function construct(n::Node{:float_literal}, stream)
    t = match_token(stream, :float_literal)
    d = DataNode(parse(Float64, t.lexme))
    n.children = [d]
end

function construct(n::Node{:identifier}, stream)
    t = match_token(stream, :identifier)
    d = DataNode(t.lexme)
    n.children = [d]
end

function construct(n::Node{:model}, stream)
    match_many!(n.children, stream, :predicate_item)
    match_many!(n.children, stream, :par_decl_item)
    match_many!(n.children, stream, :var_decl_item)
    match_many!(n.children, stream, :constraint_item)
end

function construct(n::Node{:predicate_item}, stream)
    match_token(stream, :keyword, "predicate")
    match!(n.children, stream, :identifier)
    match_token(stream, :parentheses_l)

    while true
        match!(n.children, stream, :pred_param_type)
        match_token(stream, :colon)
        match!(n.children, stream, :identifier)

        comma = match_token(stream, :comma, needsmatch=false)
        if comma === nothing
            match_token(stream, :parentheses_r)
            break
        end
        closing = match_token(stream, :parentheses_r, needsmatch=false)
        if closing !== nothing
            # found closing delim
            break
        end
    end
    match_token(stream, :semicolon)
end

function construct(n::Node{:pred_param_type}, stream)
    if match!(n.children, stream, :basic_pred_param_type, needsmatch=false) !== nothing
        return
    elseif match_token(stream, :keyword, "array", needsmatch=false) !== nothing
        match_token(stream, :bracket_l)
        match!(n.children, stream , :pred_index_set)
        match_token(stream, :bracket_r)
        match_token(stream, :keyword, "of")
        match!(n.children, stream, :basic_pred_param_type)
        return
    end
    throw(ParsingError("Could not construct :pred_param_type", stream))
end

function construct(n::Node{:pred_index_set}, stream)
    t = match_token(stream, :basic_par_type, "int")
    if t  !== nothing
        d = DataNode(t.lexme)
        n.children = [d]
        return
    elseif match!(n.children, stream, :index_set, needsmatch=false) !==nothing
        return
    end
    throw(ParsingError("Could not construct :pred_index_set", stream))
end

function construct(n::Node{:index_set}, stream)
    match_token(stream, :int_literal, "1")
    match_token(stream, :dotdot)
    match!(n.children, stream, :int_literal)
end

function construct(n::Node{:basic_pred_param_type}, stream)
    # try to match basic_par_type
    if match!(n.children, stream, :basic_par_type, needsmatch=false) !== nothing
        return
    elseif match!(n.children, stream, :basic_var_type, needsmatch=false) !== nothing
        return
    end

    # XXX: i don't get the meaning of this shortcut, is ist netccessary?
    if match_token(stream, :keyword, "var", needsmatch=false) !== nothing
        match_token(stream, :keyword, "set")
        match_token(stream, :keyword, "of")
        match_token(stream, :basic_par_type, "int")
        push!(n.children, DataNode("var set of int"))
    end

    # XXX: interpretation: set of 1..2 means the same as 1..2 and with curly braces as well
    # whever says set shoud also say of!
    if match_token(stream, :keyword, "set", needsmatch=false) !== nothing
        match_token(stream, :keyword, "of")
    end

    # last resort: set_literal
    match!(n.children, stream, :set_literal)
end

function construct(n::Node{:basic_par_type}, stream)
    t = match_token(stream, :basic_par_type)
    d = DataNode(t.lexme)
    n.children = [d]
end

function construct(n::Node{:basic_var_type}, stream)
    match_token(stream, :keyword, "var")

    # XXX: this bit is weird, why no var <basic-par-type> ?
    t = match_token(stream, :basic_par_type, needsmatch=false)
    if t !== nothing
        if t.lexme ∈ ["bool", "int", "float"]
            d = DataNode(t.lexme)
            n.children = [d]
        else
            throw(ParsingError("Wrong content auf basic_par_type token $(t.lexme)", stream))
        end
        return
    end

    if match_token(stream, :keyword, "set", needsmatch=false) !== nothing
        match_token(stream, :keyword, "of")
    end
    # XXX: this will also match {FLoat, FLoat} which is not in the grammar
    match!(n.children, stream, :set_literal)
end

function construct(n::Node{:set_literal}, stream)
    if match_token(stream, :brace_l, needsmatch=false) !== nothing
        if peek(stream).type == :int_literal
            match_many!(n.children, stream, :int_literal, delimiter=:comma)
        elseif peek(stream).type == :float_literal
            match_many!(n.children, stream, :float_literal, delimiter=:comma)
        else
            throw(ParsingError("Could not parse set_literal!", stream))
        end
        match_token(stream, :brace_r)
        return
    elseif match!(n.children, stream, :range, needsmatch=true) !== nothing
        return
    end
    throw(ParsingError("Could not construct :set_literal", stream))
end

function construct(n::Node{:range}, stream)
    if match!(n.children, stream, :int_literal, needsmatch=false) !== nothing
        match_token(stream, :dotdot)
        match!(n.children, stream, :int_literal)
        return
    elseif match!(n.children, stream, :float_literal, needsmatch=false) !== nothing
        match_token(stream, :dotdot)
        match!(n.children, stream, :float_literal)
        return
    end
    throw(ParsingError("Could not construct :range", stream))
end

function construct(n::Node{:par_decl_item}, stream)
    match!(n.children, stream, :par_type)
    match_token(stream, :colon)
    match!(n.children, stream, :identifier)
    match_token(stream, :equalsign)
    match!(n.children, stream, :par_expr)
    match_token(stream, :semicolon)
end

function construct(n::Node{:par_type}, stream)
    if match!(n.children, stream, :basic_par_type, needsmatch=false) !== nothing
        return
    elseif match_token(stream, :keyword, "array", needsmatch=false) !== nothing
        match_token(stream, :bracket_l)
        match!(n.children, stream, :index_set)
        match_token(stream, :bracket_r)
        match_token(stream, :keyword, "of")
        match!(n.children, stream, :basic_par_type)
        return
    end
    throw(ParsingError("Could not construct :par_type", stream))
end

function construct(n::Node{:par_expr}, stream)
    if match!(n.children, stream, :basic_literal_expr, needsmatch=false) !== nothing
        return
    elseif match!(n.children, stream, :par_array_literal, needsmatch=false) !== nothing
        return
    end
    throw(ParsingError("Could not construct :par_expr", stream))
end

function construct(n::Node{:basic_literal_expr}, stream)
    if match!(n.children, stream, :set_literal, needsmatch=false) !== nothing
        return
    elseif match!(n.children, stream, :bool_literal, needsmatch=false) !== nothing
        return
    elseif match!(n.children, stream, :int_literal, needsmatch=false) !== nothing
        return
    elseif match!(n.children, stream, :float_literal, needsmatch=false) !== nothing
        return
    end
    throw(ParsingError("Could not construct :basic_literal_expr", stream))
end

function construct(n::Node{:par_array_literal}, stream)
    match_token(stream, :bracket_l)
    match_many!(n.children, stream, :basic_literal_expr, delimiter=:comma)
    match_token(stream, :bracket_r)
end

function construct(n::Node{:var_decl_item}, stream)
    if match!(n.children, stream, :basic_var_type, needsmatch=false) !== nothing
        match_token(stream, :colon)
        match!(n.children, stream, :identifier)
        # well the type annotions is required but might be empty
        match!(n.children, stream, :annotations, needsmatch=false)
        if match_token(stream, :equalsign, needsmatch=false) !== nothing
            match!(n.children, stream, :par_expr)
        end
        match_token(stream, :semicolon)
        return
    elseif match!(n.children, stream, :array_var_type, needsmatch=false) !== nothing
        match_token(stream, :colon)
        match!(n.children, stream, :identifier)
        # well the type annotions is required but might be empty
        match!(n.children, stream, :annotations, needsmatch=false)
        match_token(stream, :equalsign)
        match!(n.children, stream, :array_literal)
        match_token(stream, :semicolon)
        return
    end
    throw(ParsingError("Could not construct :var_decl_item", stream))
end

function construct(n::Node{:array_var_type}, stream)
    match_token(stream, :keyword, "array")
    match_token(stream, :bracket_l)
    match!(n.children, stream, :index_set)
    match_token(stream, :bracket_r)
    match_token(stream, :keyword, "of")
    match!(n.children, stream, :basic_var_type)
end

function construct(n::Node{:array_literal}, stream)
    # needs to start with [
    match_token(stream, :bracket_l)
    match_many!(n.children, stream, :basic_expr, delimiter=:comma)
    match_token(stream, :bracket_r)
end

function construct(n::Node{:annotations}, stream)
    # needs to start with doublecolon
    match_token(stream, :doublecolon, needsmatch=true)
    match_many!(n.children, stream, :annotation; delimiter=:doublecolon, needsmatch=true)
end

function construct(n::Node{:annotation}, stream)
    # needs to start with identifier
    match!(n.children, stream, :identifier)
    if match_token(stream, :parentheses_l) !== nothing
        match_many!(n.children, stream, :ann_expr, delimiter=:comma)
        match_token(stream, :parentheses_r)
    end
end

function construct(n::Node{:ann_expr}, stream)
    if match!(n.children, stream, :expr, needsmatch=false) !== nothing
        return
    elseif match!(n.children, stream, :annotation, needsmatch=false) !== nothing
        return
    end
    throw(ParsingError("Could not construct :ann_expr", stream))
end

function construct(n::Node{:expr}, stream)
    if match!(n.children, stream, :basic_expr, needsmatch=false) !== nothing
        return
    elseif match!(n.children, stream, :array_literal, needsmatch=false) !== nothing
        return
    end
    throw(ParsingError("Could not construct :expr", stream))
end

function construct(n::Node{:basic_expr}, stream)
    if match!(n.children, stream, :basic_literal_expr, needsmatch=false) !== nothing
        return
    elseif match!(n.children, stream, :identifier, needsmatch=false) !== nothing
        return
    end
    throw(ParsingError("Could not construct :basic_expr", stream))
end

function construct(n::Node{:constraint_item}, stream)
    match_token(stream, :keyword, "constraint")
    match!(n.children, stream, :identifier)
    match_token(stream, :parentheses_l)
    match_many!(n.children, stream, :expr, delimiter=:comma)
    match_token(stream, :parentheses_r)
    match!(n.children, stream, :annotations, needsmatch=false) #technically nm=true
    match_token(stream, :semicolon)
end