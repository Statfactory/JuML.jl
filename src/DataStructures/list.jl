# abstract type List{T} end

# struct EmptyList{T} <: List{T} end

# struct ConsList{T} <: List{T}
#     head::T
#     tail::List{T}
# end

# ConsList{T}(a::T) = ConsList(a, EmptyList{T}())

# Base.:+(head::T, tail::List{T}) where {T} = ConsList(head, tail)

# Base.:+(a::List{T}, b::T) where {T} = a + ConsList(b)

# Base.:+(a::EmptyList{T}, b::List{T}) where {T} = b

# Base.:+(a::ConsList{T}, b::List{T}) where {T} = ConsList(a.head, a.tail + b)

# rev(a::EmptyList{T}) where {T} = a

# rev(a::ConsList{T}) where {T} = rev(a.tail) + ConsList(a.head)
