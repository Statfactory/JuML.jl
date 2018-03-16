mutable struct CachedCovariate{T<:AbstractFloat} <: AbstractCovariate{T}
    cache::Nullable{SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}}
    basecovariate::AbstractCovariate{T}
    lockobj::Threads.TatasLock
end

Base.length(var::CachedCovariate) = length(var.basecovariate)

getname(var::CachedCovariate) = getname(var.basecovariate)

function CachedCovariate(basecovariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    CachedCovariate{T}(Nullable{SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}}(), basecovariate, Threads.TatasLock())  
end

function cache(basecovariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    CachedCovariate{T}(Nullable{SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}}(), basecovariate, Threads.TatasLock())  
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
                v, _ = tryread(slice(basecov, 1, length(covariate), length(covariate)))
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

