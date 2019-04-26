mutable struct CachedCovariate{T<:AbstractFloat} <: AbstractCovariate{T}
    cache::Union{Vector{T}, Nothing}
    basecovariate::AbstractCovariate{T}
    lockobj::Threads.TatasLock
end

Base.length(var::CachedCovariate) = length(var.basecovariate)

getname(var::CachedCovariate) = getname(var.basecovariate)

function CachedCovariate(basecovariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    CachedCovariate{T}(nothing, basecovariate, Threads.TatasLock())  
end

function cache(basecovariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    CachedCovariate{T}(nothing, basecovariate, Threads.TatasLock())  
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
            if covariate.cache === nothing
                slices = slice(basecov, 1, length(basecov), SLICELENGTH)
                cachedata = Vector{T}(undef, length(basecov))
                fold(0, slices) do offset, slice
                    n = length(slice)
                    view(cachedata, (1 + offset):(n + offset)) .= slice
                    offset += n
                end
                covariate.cache = cachedata
            end
        finally
            unlock(lockobj)
        end
        slice(covariate.cache, fromobs, toobs, slicelength)
    end
end

function Base.map(covariate::CachedCovariate, dataframe::AbstractDataFrame)
    CachedCovariate(map(covariate.basecovariate, dataframe))
end

