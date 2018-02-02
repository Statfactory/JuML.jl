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
                            k = n
                            chunk = Vector{T}()
                            newstate = s
                            while k >= 1
                                v, newstate = next(newstate)
                                if !isnull(v)
                                    push!(chunk, get(v))
                                    k -= 1
                                else
                                    k = 0
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

function zip2(xs::Seq{T}, ys::Seq{S}) where {T} where {S}
    EmptySeq{Tuple{T, S}}()
end

function zip2(xs::ConsSeq{T}, ys::ConsSeq{S}) where {T} where {S}
    return ConsSeq{Tuple{T, S}}(() ->
            begin
                statex, nextx = xs.genfun()
                statey, nexty = ys.genfun()
                (statex, statey), state -> 
                    begin
                        _statex, _statey = state
                        x, newstatex = nextx(_statex) 
                        y, newstatey = nexty(_statey) 
                        if isnull(x) || isnull(y)
                            Nullable{Tuple{T, S}}(), (newstatex, newstatey)
                        else
                            Nullable{Tuple{T, S}}((get(x), get(y))), (newstatex, newstatey)
                        end
                    end
            end
            )
end

function zip3(xs::Seq{T}, ys::Seq{S}, zs::Seq{U}) where {T} where {S} where {U}
    EmptySeq{Tuple{T, S, U}}()
end

function zip3(xs::ConsSeq{T}, ys::ConsSeq{S}, zs::ConsSeq{U}) where {T} where {S} where {U}
    return ConsSeq{Tuple{T, S, U}}(() ->
            begin
                statex, nextx = xs.genfun()
                statey, nexty = ys.genfun()
                statez, nextz = zs.genfun()
                (statex, statey, statez), state -> 
                    begin
                        _statex, _statey, _statez = state
                        x, newstatex = nextx(_statex) 
                        y, newstatey = nexty(_statey) 
                        z, newstatez = nextz(_statez) 
                        if isnull(x) || isnull(y) || isnull(z)
                            Nullable{Tuple{T, S, U}}(), (newstatex, newstatey, newstatez)
                        else
                            Nullable{Tuple{T, S, U}}((get(x), get(y), get(z))), (newstatex, newstatey, newstatez)
                        end
                    end
            end
            )
end

function zip4(xs::Seq{T}, ys::Seq{S}, zs::Seq{U}, vs::Seq{V}) where {T} where {S} where {U} where {V}
    EmptySeq{Tuple{T, S, U, V}}()
end

function zip4(xs::ConsSeq{T}, ys::ConsSeq{S}, zs::ConsSeq{U}, vs::Seq{V}) where {T} where {S} where {U} where {V}
    return ConsSeq{Tuple{T, S, U, V}}(() ->
            begin
                statex, nextx = xs.genfun()
                statey, nexty = ys.genfun()
                statez, nextz = zs.genfun()
                statev, nextv = vs.genfun()
                (statex, statey, statez, statev), state -> 
                    begin
                        _statex, _statey, _statez, _statev = state
                        x, newstatex = nextx(_statex) 
                        y, newstatey = nexty(_statey) 
                        z, newstatez = nextz(_statez) 
                        v, newstatev = nextv(_statev) 
                        if isnull(x) || isnull(y) || isnull(z) || isnull(v)
                            Nullable{Tuple{T, S, U, V}}(), (newstatex, newstatey, newstatez, newstatev)
                        else
                            Nullable{Tuple{T, S, U, V}}((get(x), get(y), get(z), get(v))), (newstatex, newstatey, newstatez, newstatev)
                        end
                    end
            end
            )
end


function zipn(xs::Vector{<:Seq{T}}) where {T}
    EmptySeq{Vector{T}}()
end

function zipn(xs::Vector{ConsSeq{T}}) where {T}
    return ConsSeq{Vector{T}}(() ->
        begin
            y = [x.genfun() for x in xs]
            state = [s for (s, _) in y]
            next = [f for (_, f) in y]
            state, sarg ->
                begin
                    res = [b(a) for (a, b) in zip(sarg, next)]
                    newstate = [x for (_, x) in res]
                    if all([!isnull(a) for (a, b) in res])
                        v = [get(x) for (x, _) in res]
                        Nullable{Vector{T}}(v), newstate
                    else
                        Nullable{Vector{T}}(), newstate
                    end
                end
        end
    )
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


