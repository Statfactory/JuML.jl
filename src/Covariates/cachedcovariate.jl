mutable struct CachedCovariate{T<:AbstractFloat} <: AbstractCovariate{T}
    cache::Nullable{AbstractVector{T}}
    basecovariate::AbstractCovariate{T}
    lockobj::Threads.TatasLock
end

Base.length(var::CachedCovariate) = length(var.basecovariate)

getname(var::CachedCovariate) = getname(var.basecovariate)

function CachedCovariate(basecovariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    CachedCovariate{T}(Nullable{AbstractVector{T}}(), basecovariate, Threads.TatasLock())  
end

function cache(basecovariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    CachedCovariate{T}(Nullable{AbstractVector{T}}(), basecovariate, Threads.TatasLock())  
end

function slice(covariate::CachedCovariate{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat}
    basecov = covariate.basecovariate
    if isa(basecov, CachedCovariate) || isa(basecov, Covariate)
        slice(basecov, fromobs, toobs, slicelength)
    else
        lockobj = covariate.lockobj
        lock(lockobj)
        try
            if isnull(covariate.cache)
                v, _ = tryread(slice(basecov, 1, length(basecov), length(basecov)))
                covariate.cache = v
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

