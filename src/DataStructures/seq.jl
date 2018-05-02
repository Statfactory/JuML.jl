import Base.Iterators

abstract type Seq{T} end

struct EmptySeq{T} <: Seq{T} end

struct ConsSeq{T} <: Seq{T}
    genfun::Function
end

function Seq(::Type{T}, state, next::Function) where {T}
    ConsSeq{T}(() -> (state, next))
end

function Seq(::Type{T}, iter) where {T}
    ConsSeq{T}( () -> (start(iter), 
                       state -> done(iter, state) ?
                       (Nullable{T}(), state) :
                       begin
                           v, newstate = next(iter, state)
                           Nullable{T}(v), newstate
                       end))
end

function Base.eltype(x::Seq{T}) where {T}
    T
end

function Seq(range::Range{T}) where {T}
    Seq(T, range)
end

tryread(s::EmptySeq{T}) where {T} = Nullable{T}(), EmptySeq{T}()

function tryread(xs::ConsSeq{T}) where {T} 
    state, next = xs.genfun()
    v, newstate = next(state)
    if isnull(v)
        Nullable{T}(), EmptySeq{T}()
    else
        v, ConsSeq{T}(() -> (newstate, next))
    end
end

Base.map(f::Function, xs::EmptySeq{T}, ::Type{S}) where {T, S} = EmptySeq{S}()

Base.map(f::Function, xs::EmptySeq{T}) where {T} = EmptySeq{T}()

function Base.map(f::Function, xs::ConsSeq{T}, ::Type{S}) where {T, S} 
    ConsSeq{S}(() -> 
                begin
                    state, next = xs.genfun()
                    state, s -> begin
                                    v, newstate = next(s)
                                    map(f, v), newstate
                                end
                end
              )
end

function Base.map(f::Function, xs::ConsSeq{T}) where {T} 
    map(f, xs, T)
end

fold(f::Function, init, xs::EmptySeq{T}) where {T} = init

function fold(f::Function, init, xs::ConsSeq{T}) where {T}
    eof = false
    acc = init
    tail = xs
    while !eof
        v, tail = tryread(tail)
        if isnull(v)
            eof = true
        else
            acc = f(acc, get(v))
        end
    end
    acc
end

function iter(f::Function, xs::ConsSeq{T}) where {T}
    eof = false
    tail = xs
    while !eof
        v, tail = tryread(tail)
        if isnull(v)
            eof = true
        else
            f(get(v))
        end
    end
end

Iterators.take(xs::EmptySeq{T}, n::Integer) where {T} = EmptySeq{T}()

function Iterators.take(xs::ConsSeq{T}, n::Integer) where {T}
    ConsSeq{T}(() -> 
                    begin
                        state, next = xs.genfun()
                        (state, n), s -> begin
                                             state = s[1]
                                             n = s[2]
                                             if n >= 1
                                                v, newstate = next(state)
                                                v, (newstate, n - 1)
                                             else
                                                 Nullable{T}(), state
                                             end
                                    end
                    end
             )
end

function chunkbysize(xs::EmptySeq{T}, n::Integer) where {T} 
    EmptySeq{Vector{T}}()
end

function chunkbysize(xs::ConsSeq{T}, n::Integer) where {T} 
    return ConsSeq{Vector{T}}(() ->
        begin
            state, next = xs.genfun()
            state, s -> begin
                            chunk = Vector{T}(n)
                            newstate = s
                            for k in 1:n
                                v, newstate = next(newstate)
                                if !isnull(v)
                                    chunk[k] = get(v)
                                else
                                    resize!(chunk, k - 1)
                                    break
                                end
                            end
                            if length(chunk) == 0
                                Nullable{Vector{T}}(), newstate
                            else
                                Nullable{Vector{T}}(chunk), newstate
                            end
                        end
        end)
end

function Base.zip(xs::NTuple{N, Seq}) where {N}
    eltypes = map(eltype, xs)
    EmptySeq{Tuple{eltypes...}}()
end

function Base.zip(xs::NTuple{N, ConsSeq}) where {N}
    eltypes = map(eltype, xs)
    return ConsSeq{Tuple{eltypes...}}(() ->
        begin
            y = map((x -> x.genfun()), xs)
            state = map((x -> x[1]), y)
            next = map((x -> x[2]), y)
            state, sarg ->
                begin
                    res = map((x -> x[2](x[1])), zip(sarg, next))
                    newstate = map((x -> x[2]), res)
                    if all([!isnull(a) for (a, b) in res])
                        v = map((x -> get(x[1])), res)
                        Nullable{Tuple{eltypes...}}(Tuple(v)), newstate
                    else
                        Nullable{Tuple{eltypes...}}(), newstate
                    end
                end
        end
    )
end

function Base.zip(xs::Seq...)
    Base.zip(xs)
end

function Base.zip(xs::ConsSeq...)
    Base.zip(xs)
end

function Base.foreach(f::Function, xs::Seq{T}) where {T}
    eof = false
    tail = xs
    while !eof
        v, tail = tryread(tail)
        if isnull(v)
            eof = true
        else
            f(get(v))
        end
    end   
end

function Base.collect(xs::Seq{T}) where {T}
    res = Vector{T}()
    eof = false
    tail = xs
    while !eof
        v, tail = tryread(tail)
        if isnull(v)
            eof = true
        else
            push!(res, get(v))
        end
    end  
    res
end

function concat(xs::EmptySeq{T}, ys::Seq{T}) where {T}
    ys
end

function concat(xs::Seq{T}, ys::EmptySeq{T}) where {T}
    xs
end

function concat(xs::ConsSeq{T}, ys::ConsSeq{T}) where {T}
    return ConsSeq{T}(() ->
            begin
                statex, nextx = xs.genfun()
                statey, nexty = ys.genfun()
                (statex, statey), s -> 
                    begin
                        _statex, _statey = s
                        x, newstatex = nextx(_statex) 
                        if isnull(x)
                            y, newstatey = nexty(_statey) 
                            if isnull(y)
                                Nullable{T}(), (newstatex, newstatey)
                            else
                                Nullable{T}(get(y)), (newstatex, newstatey)
                            end
                        else
                            Nullable{T}(get(x)), (newstatex, _statey)
                        end
                    end
            end
            )
end


