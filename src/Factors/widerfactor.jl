# struct WiderFactor{S<:Unsigned, T<:Unsigned} <: AbstractFactor{T}
#     basefactor::AbstractFactor{S}
# end

# Base.length(factor::WiderFactor{S, T}) where {S<:Unsigned} where {T<:Unsigned} = length(factor.basefactor)

# getlevels(factor::WiderFactor{S, T}) where {S<:Unsigned} where {T<:Unsigned} = getlevels(factor.basefactor)

# getname(factor::WiderFactor{S, T}) where {S<:Unsigned} where {T<:Unsigned} = getname(factor.basefactor)

# function slice(factor::WiderFactor{S, T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {S<:Unsigned} where {T<:Unsigned}
#     slicelength = verifyslicelength(fromobs, toobs, slicelength)
#     if S == T
#         slice(factor.basefactor, fromobs, toobs, slicelength)
#     else
#         f = x -> convert(T, x)
#         mapslice(f, slice(factor.basefactor, fromobs, toobs, slicelength), slicelength, T)  
#     end
# end

# function Base.convert(::Type{WiderFactor{S, T}}, x::AbstractFactor{S}) where {S<:Unsigned} where {T<:Unsigned}
#     WiderFactor{S, T}(x)
# end

# function Base.map(factor::WiderFactor, dataframe::AbstractDataFrame) 
#     map(factor.basefactor, dataframe)
# end

# function isordinal(factor::WiderFactor)
#     isordinal(factor.basefactor)
# end