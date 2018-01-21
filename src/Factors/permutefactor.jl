struct PermuteFactor{S<:Unsigned, T<:Unsigned} <: AbstractFactor{T}
    name::String
    levels::AbstractVector{<:AbstractString}
    basefactor::AbstractFactor{S}
    newindex::Vector{T}
end

Base.length(factor::PermuteFactor{T}) where {T<:Unsigned} = length(factor.basefactor)

function PermuteFactor(name::String, basefactor::AbstractFactor{T}, islessfun::Function) where {T<:Unsigned}
    baselevels = getlevels(basefactor)
    levelcount = length(baselevels)
    perm = sortperm(baselevels, lt = islessfun)
    sortlevels = baselevels[perm]
    newindex = Vector{T}(levelcount + 1)
    newindex[1] = 0
    for i in 1:levelcount
        newindex[i + 1] = perm[i]
    end
    PermuteFactor{T, T}(name, sortlevels, basefactor, newindex)
end

function PermuteFactor(name::String, basefactor::AbstractFactor{T}) where {T<:Unsigned}
    PermuteFactor{T}(name, basefactor, isless)
end

function slice(factor::PermuteFactor{S, T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned} where {S<:Unsigned}
    newindex = factor.newindex
    f = (i::S -> newindex[i + 1])
    slices = slice(factor.basefactor, fromobs, toobs, slicelength)
    mapslice(f, slices, slicelength, T)
end