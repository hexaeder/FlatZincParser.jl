using AbstractTrees


"Supertype for all nodes"
abstract type AbstractNode end


"""
    DataNode{D} <: AbstractNode

Holds literal data of type D
"""
struct DataNode{D} <: AbstractNode
    data::D
end

Base.:(==)(n1::T, n2::T) where {T<:DataNode} = n1.data == n2.data

AbstractTrees.printnode(io::IO, node::DataNode) = print(io, node.data)


"""
    Node{T} <: Abstract Node

Holds children as vector. Type parameter `T` is a
symbol to represent the node type.
"""
mutable struct Node{T} <: AbstractNode
    children::Vector{AbstractNode}
    Node(type) = new{type}(AbstractNode[])
end

Base.:(==)(n1::T, n2::T) where {T<:Node} = n1.children == n2.children

type(::Node{T}) where {T} = T

AbstractTrees.children(node::Node) = node.children
AbstractTrees.printnode(io::IO, node::Node) = print(io, type(node))

function Base.match(stream::TokenStream, type::Symbol;  kwargs...)
    children = AbstractNode[]
    match!(children, stream, type; kwargs...)
end

function match!(children, stream::TokenStream, type::Symbol; needsmatch=true)
    candidate = Node(type)
    pos = position(stream)
    try
        construct(candidate, stream)
        push!(children, candidate)
        return candidate
    catch err
        if err isa ParsingError && !needsmatch
            setposition!(stream, pos) # reset! stream position
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
        return next!(stream)
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

function construct(n::Node{:string_literal}, stream)
    t = match_token(stream, :string_literal)
    d = DataNode(t.lexme)
    n.children = [d]
end

function construct(n::Node{:identifier}, stream)
    t = match_token(stream, :identifier)
    d = DataNode(t.lexme)
    n.children = [d]
end

function construct(n::Node{:model}, stream)
    match_many!(n.children, stream, :predicate_item, needsmatch=false)
    match_many!(n.children, stream, :par_decl_item, needsmatch=false)
    match_many!(n.children, stream, :var_decl_item, needsmatch=false)
    match_many!(n.children, stream, :constraint_item, needsmatch=false)
    match!(n.children, stream, :solve_item)
end

function construct(n::Node{:fullline}, stream)
    if match!(n.children, stream, :constraint_item, needsmatch=false) !== nothing
        return
    elseif match!(n.children, stream, :predicate_item, needsmatch=false) !== nothing
        return
    elseif match!(n.children, stream, :par_decl_item, needsmatch=false) !== nothing
        return
    elseif match!(n.children, stream, :var_decl_item, needsmatch=false) !== nothing
        return
    elseif match!(n.children, stream, :solve_item) !== nothing
        return
    end
    throw(ParsingError("Could not construct :fullline", stream))
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

    # int or float range without "set of"
    if match!(n.children, stream, :range, needsmatch=false) !== nothing
        return
    end

    if match_token(stream, :brace_l, needsmatch=false) !== nothing
        match_many!(n.children, stream, :int_literal, delimiter=:comma)
        match_token(stream, :brace_r)
        return
    end

    # must be one of the "set of" options, designated with its own Symbol
    # XXX: more elegant solution would be to catch "set of .." in lexer,
    # but with the spaces this is somewhat tricky
    if match!(n.children, stream, :set_of_var_basic_var_type, needsmatch=false) !== nothing
        return
    end

    throw(ParsingError("Could not construct :basic_pred_param_type", stream))
end

function construct(n::Node{:basic_par_type}, stream)
    if match_token(stream, :keyword, "set", needsmatch=false) !== nothing
        match_token(stream, :keyword, "of")

        # workaround to lexer not managing "set of int" as type, as it's multi-word
        t = match_token(stream, :basic_par_type)
        if t.lexme != "int"
            throw(ParsingError("Could not construct :basic_par_type", stream))
        end
        d = DataNode("set of int")
        n.children = [d]
    else
        t = match_token(stream, :basic_par_type)
        d = DataNode(t.lexme)
        n.children = [d]
    end
end

function construct(n::Node{:basic_var_type}, stream)
    match_token(stream, :keyword, "var")

    if match!(n.children, stream, :basic_par_type, needsmatch=false) !== nothing
        return
    end

    # int or float range without "set of"
    if match!(n.children, stream, :range, needsmatch=false) !== nothing
        return
    end

    if match_token(stream, :brace_l, needsmatch=false) !== nothing
        match_many!(n.children, stream, :int_literal, delimiter=:comma)
        match_token(stream, :brace_r)
        return
    end

    # must be one of the "set of" options, designated with its own Symbol
    if match!(n.children, stream, :set_of_var_basic_var_type, needsmatch=false) !== nothing
        return
    end

    throw(ParsingError("Could not construct :basic_var_type", stream))
end

function construct(n::Node{:set_of_var_basic_var_type}, stream)
    match_token(stream, :keyword, "set")
    match_token(stream, :keyword, "of")

    if match_token(stream, :brace_l, needsmatch=false) !== nothing
        match_many!(n.children, stream, :int_literal, delimiter=:comma)
        match_token(stream, :brace_r)
        return
    else
        # XXX: this will also match {Float, Float} which is not in the grammar
        match!(n.children, stream, :range, needsmatch=true) !== nothing
        return
    end
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
    match_many!(n.children, stream, :basic_expr, needsmatch=false, delimiter=:comma)
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
    if match_token(stream, :parentheses_l, needsmatch=false) !== nothing
        match_many!(n.children, stream, :ann_expr, delimiter=:comma)
        match_token(stream, :parentheses_r)
    end
end

function construct(n::Node{:basic_ann_expr_list}, stream)
    match_token(stream, :bracket_l)
    match_many!(n.children, stream, :basic_ann_expr, delimiter=:comma)
    match_token(stream, :bracket_r)
end

function construct(n::Node{:ann_expr}, stream)
    if match!(n.children, stream, :basic_ann_expr, needsmatch=false) !== nothing
        return
    elseif peek(stream).type == :bracket_l
        match!(n.children, stream, :basic_ann_expr_list, needsmatch=true)
        return
    end
    throw(ParsingError("Could not construct :ann_expr", stream))
end

function construct(n::Node{:basic_ann_expr}, stream)
    if match!(n.children, stream, :annotation, needsmatch=false) !== nothing
        return
    elseif match!(n.children, stream, :basic_literal_expr, needsmatch=false) !== nothing
        return
    elseif match!(n.children, stream, :string_literal, needsmatch=false) !== nothing
        return
    end
    throw(ParsingError("Could not construct :basic_ann_expr", stream))
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

function construct(n::Node{:solve_item}, stream)
    match_token(stream, :keyword, "solve")
    match!(n.children, stream, :annotations, needsmatch=false) #technically nm=true
    if match_token(stream, :keyword, "satisfy", needsmatch=false) !== nothing
        d = Node(:satisfy)
        push!(n.children, d)
    elseif match_token(stream, :keyword, "minimize", needsmatch=false) !== nothing
        match!(n.children, stream, :basic_expr)
        d = Node(:minimize)
        push!(n.children, d)
    elseif match_token(stream, :keyword, "maximize", needsmatch=false) !== nothing
        match!(n.children, stream, :basic_expr)
        d = Node(:maximize)
        push!(n.children, d)
    else
        throw(ParsingError("Could not construct :solve_item", stream))
    end
    match_token(stream, :semicolon)
end
