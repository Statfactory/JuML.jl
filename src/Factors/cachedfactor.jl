mutable struct CachedFactor{T<:Unsigned} <: AbstractFactor{T}
    cache::Union{Vector{T}, Nothing}
    basefactor::AbstractFactor{T}
    lockobj::Threads.TatasLock
end

Base.length(var::CachedFactor) = length(var.basefactor)

getname(var::CachedFactor) = getname(var.basefactor)

getlevels(var::CachedFactor) = getlevels(var.basefactor)

function CachedFactor(factor::AbstractFactor{T}) where {T<:Unsigned}
    CachedFactor{T}(nothing, factor, Threads.TatasLock()) 
end

function cache(basefactor::AbstractFactor{T}) where {T<:Unsigned}
    CachedFactor{T}(nothing, basefactor, Threads.TatasLock()) 
end

function slice(factor::CachedFactor{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned}
    basefactor = factor.basefactor
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    if isa(basefactor, CachedFactor) || isa(basefactor, Factor)
        slice(basefactor, fromobs, toobs, slicelength)
    else
        lockobj = factor.lockobj
        lock(lockobj)
        try
            if factor.cache === nothing
                slices = slice(basefactor, 1, length(basefactor), SLICELENGTH)
                cachedata = Vector{T}(undef, length(basefactor))
                fold(0, slices) do offset, slice
                    n = length(slice)
                    view(cachedata, (1 + offset):(n + offset)) .= slice
                    offset += n
                end
                factor.cache = cachedata
            end
        finally
            unlock(lockobj)
        end
        slice(factor.cache, fromobs, toobs, slicelength)
    end
end

function Base.map(factor::CachedFactor{T}, dataframe::AbstractDataFrame; permute::Bool = false) where {T<:Unsigned}
    CachedFactor(map(factor.basefactor, dataframe; permute = permute))
end

function isordinal(factor::CachedFactor{T}) where {T<:Unsigned}
    isordinal(factor.basefactor)
end