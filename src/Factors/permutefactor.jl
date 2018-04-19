struct PermuteFactor{S<:Unsigned, T<:Unsigned} <: AbstractFactor{T}
    name::String
    levels::AbstractVector{<:AbstractString}
    basefactor::AbstractFactor{S}
    newindex::Vector{T}
end

Base.length(factor::PermuteFactor{T}) where {T<:Unsigned} = length(factor.basefactor)

function slice(factor::PermuteFactor{S, T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned} where {S<:Unsigned}
    newindex = factor.newindex
    f = (i::S -> newindex[i + 1])
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = slice(factor.basefactor, fromobs, toobs, slicelength)
    mapslice(f, slices, slicelength, T)
end

function PermuteFactor(basefactor::AbstractFactor{T}, factortopermute::AbstractFactor{S}) where {T<:Unsigned} where {S<:Unsigned}
    baselevels = getlevels(basefactor)
    baselen = length(baselevels)
    permlevels = getlevels(factortopermute)
    unionlevels = union(Set(baselevels), Set(permlevels))
    difflevels = [x for x in setdiff(unionlevels, Set(baselevels))]
    levels = [i <= baselen ? baselevels[i] : difflevels[i - baselen] for i in 1:length(unionlevels)]
    newindex = [i == 0 ? 0 : findfirst(levels, permlevels[i]) for i in 0:length(permlevels)]
    if length(levels) <= typemax(UInt8)
        PermuteFactor{S, UInt8}(getname(factortopermute), levels, factortopermute, convert(Vector{UInt8}, newindex))
    elseif length(levels) <= typemax(UInt16)
        PermuteFactor{S, UInt16}(getname(factortopermute), levels, factortopermute, convert(Vector{UInt16}, newindex))
    else
        PermuteFactor{S, UInt32}(getname(factortopermute), levels, factortopermute, convert(Vector{UInt32}, newindex))
    end
end

function Base.map(factor::PermuteFactor, dataframe::AbstractDataFrame)
    islessfun = (x, y) -> isless(findfirst(factor.levels, x), findfirst(factor.levels, y))
    OrdinalFactor(factor.name, map(factor.basefactor, dataframe), islessfun)
end