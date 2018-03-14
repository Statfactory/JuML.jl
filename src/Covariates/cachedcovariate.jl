mutable struct CachedCovariate{T<:AbstractFloat} <: AbstractCovariate{T}
    cache::Dict{Tuple{Int64, Int64}, SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}}
    basecovariate::AbstractCovariate{T}
    lockobj::Threads.TatasLock
end

Base.length(var::CachedCovariate) = length(var.basecovariate)

getname(var::CachedCovariate) = getname(var.basecovariate)

function CachedCovariate(basecovariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    CachedCovariate{T}(Dict{Tuple{Int64, Int64}, SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}}(), basecovariate, Threads.TatasLock())  
end

function cache(basecovariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    CachedCovariate{T}(Dict{Tuple{Int64, Int64}, SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}}(), basecovariate, Threads.TatasLock())  
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
            if !((fromobs, toobs) in keys(covariate.cache))
                v, _ = tryread(slice(basecov, fromobs, toobs, toobs - fromobs + 1))
                covariate.cache[(fromobs, toobs)] = get(v)
            end
        finally
            unlock(lockobj)
        end
        slice(covariate.cache[(fromobs, toobs)], 1, toobs - fromobs + 1, slicelength)
    end
end

function Base.map(covariate::CachedCovariate, dataframe::AbstractDataFrame)
    CachedCovariate(map(covariate.basecovariate, dataframe))
end

