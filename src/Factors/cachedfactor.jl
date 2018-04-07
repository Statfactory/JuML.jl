mutable struct CachedFactor{T<:Unsigned} <: AbstractFactor{T}
    cache::Nullable{Vector{T}}
    basefactor::AbstractFactor{T}
    lockobj::Threads.TatasLock
end

Base.length(var::CachedFactor) = length(var.basefactor)

getname(var::CachedFactor) = getname(var.basefactor)

getlevels(var::CachedFactor) = getlevels(var.basefactor)

function CachedFactor(factor::AbstractFactor{T}) where {T<:Unsigned}
    CachedFactor{T}(Nullable{Vector{T}}(), factor, Threads.TatasLock()) 
end

function cache(basefactor::AbstractFactor{T}) where {T<:Unsigned}
    CachedFactor{T}(Nullable{Vector{T}}(), basefactor, Threads.TatasLock()) 
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
            if isnull(factor.cache)
                slices = slice(basefactor, 1, length(basefactor), SLICELENGTH)
                cachedata = Vector{T}(length(basefactor))
                fold(0, slices) do offset, slice
                    n = length(slice)
                    @inbounds for i in 1:n
                        cachedata[i + offset] = slice[i]
                    end
                    offset += n
                end
                factor.cache = Nullable{Vector{T}}(cachedata)
            end
        finally
            unlock(lockobj)
        end
        slice(get(factor.cache), fromobs, toobs, slicelength)
    end
end

function Base.map(factor::CachedFactor{T}, dataframe::AbstractDataFrame) where {T<:Unsigned}
    CachedFactor(map(factor.basefactor, dataframe))
end

function isordinal(factor::CachedFactor{T}) where {T<:Unsigned}
    isordinal(factor.basefactor)
end