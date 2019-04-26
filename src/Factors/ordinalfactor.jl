struct OrdinalFactor{T<:Unsigned} <: AbstractFactor{T}
    name::String
    levels::AbstractVector{<:AbstractString}
    basefactor::AbstractFactor{T}
    newindex::Vector{T}
    islessfun::Union{Function, Nothing}
end

Base.length(factor::OrdinalFactor{T}) where {T<:Unsigned} = length(factor.basefactor)

function OrdinalFactor(name::String, basefactor::AbstractFactor{T}, islessfun::Function) where {T<:Unsigned}
    baselevels = getlevels(basefactor)
    levelcount = length(baselevels)
    perm = sortperm(baselevels, lt = islessfun)
    sortlevels = baselevels[perm]
    newindex = Vector{T}(undef, levelcount + 1)
    newindex[1] = 0
    for i in 1:levelcount
        newindex[i + 1] = perm[i]
    end
    OrdinalFactor{T}(name, sortlevels, basefactor, newindex, islessfun)
end

function OrdinalFactor(factor::AbstractFactor{T}) where {T<:Unsigned}
    OrdinalFactor{T}(getname(factor), getlevels(factor), factor, Vector{T}(), nothing)
end

function slice(factor::OrdinalFactor{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned} 
    if factor.islessfun === nothing
        slice(factor.basefactor, fromobs, toobs, slicelength)
    else
        newindex = factor.newindex
        f = (i::T -> newindex[i + one(T)])
        slicelength = verifyslicelength(fromobs, toobs, slicelength) 
        slices = slice(factor.basefactor, fromobs, toobs, slicelength)
        mapslice(f, slices, slicelength, T)
    end
end

function isordinal(factor::OrdinalFactor{T}) where {T<:Unsigned}
   true
end

function Base.map(factor::OrdinalFactor{T}, dataframe::AbstractDataFrame) where {T<:Unsigned}
    if factor.islessfun === nothing
        OrdinalFactor(map(factor.basefactor, dataframe))
    else
        OrdinalFactor(factor.name, map(factor.basefactor, dataframe), factor.islessfun)
    end
end