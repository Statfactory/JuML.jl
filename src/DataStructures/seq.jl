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
                        statex, statey = state
                        x, newstatex = nextx(statex) 
                        y, newstatey = nexty(statey) 
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
                        statex, statey, statez = state
                        x, newstatex = nextx(statex) 
                        y, newstatey = nexty(statey) 
                        z, newstatez = nextz(statez) 
                        if isnull(x) || isnull(y) || isnull(z)
                            Nullable{Tuple{T, S, U}}(), (newstatex, newstatey, newstatez)
                        else
                            Nullable{Tuple{T, S, U}}((get(x), get(y), get(z))), (newstatex, newstatey, newstatez)
                        end
                    end
            end
            )
end



# abstract type Seq{T} end

# struct EmptySeq{T} <: Seq{T} end

# struct ConsSeq{T} <: Seq{T}
#     genfun::Function
# end

# function Seq(::Type{T}, iter) where {T}
#     state = start(iter)
#     if done(iter, state)
#         EmptySeq{T}()
#     else
#         v::T, newstate = next(iter, state)
#         ConsSeq{T}( () -> (v, Seq(T, iter, newstate)))
#     end
# end

# function Seq(::Type{T}, iter, state) where {T}
#     if done(iter, state)
#         EmptySeq{T}()
#       else
#         v::T, newstate = next(iter, state)
#         ConsSeq{T}( () -> (v, Seq(T, iter, newstate)))
#       end
# end

# function Seq(::Type{T}, genfun::Function) where {T}
#     v::Nullable{T} = genfun()
#     if isnull(v)
#         EmptySeq{T}()
#     else
#         a::T = get(v)
#         ConsSeq{T}(() -> (a, Seq(T, genfun)))
#     end
# end

# tryread(s::EmptySeq{T}) where {T} = Nullable{T}(), EmptySeq{T}()

# function tryread(xs::ConsSeq{T}) where {T} 
#     v::T, tail = xs.genfun()
#     Nullable{T}(v), tail
# end

# Base.isempty(xs::EmptySeq{T}) where {T} = true

# Base.isempty(xs::ConsSeq{T}) where {T} = false

# fold(f::Function, init, xs::EmptySeq{T}) where {T} = init

# function fold(f::Function, init, xs::ConsSeq{T}) where {T}
#     eof = false
#     acc = init
#     tail = xs
#     while !eof
#         v, tail = tail.genfun()
#         acc = f(acc, v)
#         eof = isempty(tail)
#     end
#     acc
# end

# Iterators.take(xs::EmptySeq{T}, n::Integer) where {T} = EmptySeq{T}()

# function Iterators.take(xs::ConsSeq{T}, n::Integer) where {T}
#     if n > 1
#         ConsSeq{T}(() ->
#             begin
#                 a, tail = xs.genfun()
#                 (a, Iterators.take(tail, n - 1))
#             end)
#     else
#         ConsSeq{T}(() ->
#             begin
#                 a, tail = xs.genfun()
#                 (a, EmptySeq{T}())
#             end)
#     end
# end

# Base.map(f::Function, xs::EmptySeq{T}, ::Type{S}) where {T, S} = EmptySeq{S}()

# function Base.map(f::Function, xs::ConsSeq{T}, ::Type{S}) where {T, S} 
#     ConsSeq{S}(() ->
#                 begin
#                     a, tail = xs.genfun()
#                     v = f(a)
#                     return (v, map(f, tail, S))
#                 end
#               )
# end

# function chunkbysize(xs::EmptySeq{T}, n::Integer) where {T} 
#     EmptySeq{Vector{T}}()
# end

# function chunkbysize(xs::ConsSeq{T}, n::Integer) where {T} 
#     return ConsSeq{Vector{T}}(() ->
#         begin
#             chunk = Vector{T}()
#             k = n
#             tail = xs
#             while k >= 1
#                 a, tail = tryread(tail)
#                 if !isnull(a)
#                     push!(chunk, get(a))
#                     k -= 1
#                 else
#                     k = 0
#                 end
#             end
#             (chunk, chunkbysize(tail, n))
#         end)
# end

# function zip2(xs::Seq{T}, ys::Seq{S}) where {T} where {S}
#     EmptySeq{Tuple{T, S}}()
# end

# function zip2(xs::ConsSeq{T}, ys::ConsSeq{S}) where {T} where {S}
#     ConsSeq{Tuple{T, S}}(() ->
#         begin
#             x, tailx = xs.genfun()
#             y, taily = ys.genfun()
#             ((x, y), zip2(tailx, taily))
#         end)
# end

# function zip3(xs::Seq{T}, ys::Seq{S}, zs::Seq{U}) where {T} where {S} where {U}
#     EmptySeq{Tuple{T, S, U}}()
# end

# function zip3(xs::ConsSeq{T}, ys::ConsSeq{S}, zs::ConsSeq{U}) where {T} where {S} where {U}
#     ConsSeq{Tuple{T, S, U}}(() ->
#         begin
#             x, tailx = xs.genfun()
#             y, taily = ys.genfun()
#             z, tailz = zs.genfun()
#             ((x, y, z), zip3(tailx, taily, tailz))
#         end)
# end
