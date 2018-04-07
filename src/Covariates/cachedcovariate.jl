mutable struct CachedCovariate{T<:AbstractFloat} <: AbstractCovariate{T}
    cache::Nullable{Vector{T}}
    basecovariate::AbstractCovariate{T}
    lockobj::Threads.TatasLock
end

Base.length(var::CachedCovariate) = length(var.basecovariate)

getname(var::CachedCovariate) = getname(var.basecovariate)

function CachedCovariate(basecovariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    CachedCovariate{T}(Nullable{Vector{T}}(), basecovariate, Threads.TatasLock())  
end

function cache(basecovariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    CachedCovariate{T}(Nullable{Vector{T}}(), basecovariate, Threads.TatasLock())  
end

function slice(covariate::CachedCovariate{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat}
    basecov = covariate.basecovariate
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    if isa(basecov, CachedCovariate) || isa(basecov, Covariate)
        slice(basecov, fromobs, toobs, slicelength)
    else
        lockobj = covariate.lockobj
        lock(lockobj)
        try
            if isnull(covariate.cache)
                slices = slice(basecov, 1, length(basecov), SLICELENGTH)
                cachedata = Vector{T}(length(basecov))
                fold(0, slices) do offset, slice
                    n = length(slice)
                    @inbounds for i in 1:n
                        cachedata[i + offset] = slice[i]
                    end
                    offset += n
                end
                covariate.cache = Nullable{Vector{T}}(cachedata)
            end
        finally
            unlock(lockobj)
        end
        slice(get(covariate.cache), fromobs, toobs, slicelength)
    end
end

function Base.map(covariate::CachedCovariate, dataframe::AbstractDataFrame)
    CachedCovariate(map(covariate.basecovariate, dataframe))
end

