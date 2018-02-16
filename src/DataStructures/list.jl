abstract type List{T} end

struct EmptyList{T} <: List{T} end

struct ConsList{T} <: List{T}
    head::T
    tail::List{T}
end

ConsList{T}(a::T) where {T} = ConsList{T}(a, EmptyList{T}())

Base.:+(head::T, tail::List{T}) where {T} = ConsList{T}(head, tail)

Base.:+(a::List{T}, b::T) where {T} = a + ConsList{T}(b)

Base.:+(a::EmptyList{T}, b::List{T}) where {T} = b

Base.:+(a::ConsList{T}, b::List{T}) where {T} = ConsList{T}(a.head, a.tail + b)

rev(a::EmptyList{T}) where {T} = a

rev(a::ConsList{T}) where {T} = rev(a.tail) + ConsList{T}(a.head)

function Base.convert(::Type{Vector{T}}, a::EmptyList{T}) where {T}
    Vector{T}()
end

function Base.convert(::Type{Vector{T}}, a::ConsList{T}) where {T}
    unshift!(convert(Vector{T}, a.tail), a.head)
end

function Base.convert(::Type{Vector{Vector{T}}}, a::List{List{T}}) where {T}
    map((x -> convert(Vector{T}, x)), convert(Vector{List{T}}, a))
end

function zip2(a::EmptyList{T}, b::EmptyList{S}) where {T} where {S}
    EmptyList{Tuple{T, S}}()
end

function zip2(a::EmptyList{T}, b::ConsList{S}) where {T} where {S}
    EmptyList{Tuple{T, S}}()
end

function zip2(a::ConsList{T}, b::EmptyList{S}) where {T} where {S}
    EmptyList{Tuple{T, S}}()
end

function zip2(a::ConsList{T}, b::ConsList{S}) where {T} where {S}
    ConsList{Tuple{T, S}}((a.head, b.head), zip2(a.tail, b.tail))
end

function Base.map(f::Function, a::EmptyList{T}, ::Type{S}) where {T} where {S}
    EmptyList{S}()  
end

function Base.map(f::Function, a::ConsList{T}, ::Type{S}) where {T} where {S}
    ConsList{S}(f(a.head), map(f, a.tail, S))
end
