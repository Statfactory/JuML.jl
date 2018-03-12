mutable struct CachedBoolVariate <: AbstractBoolVariate
    cache::Dict{Tuple{Integer, Integer}, AbstractVector{Bool}}
    basevariate::AbstractBoolVariate
    lockobj::Threads.TatasLock
end

Base.length(var::CachedBoolVariate) = length(var.basevariate)

getname(var::CachedBoolVariate) = getname(var.basevariate)

function CachedBoolVariate(basevariate::AbstractBoolVariate) 
    CachedBoolVariate(Dict{Tuple{Integer, Integer}, AbstractVector{Bool}}(), basevariate, Threads.TatasLock())  
end

function cache(basevariate::AbstractBoolVariate) 
    CachedBoolVariate(Dict{Tuple{Integer, Integer}, AbstractVector{Bool}}(), basevariate, Threads.TatasLock())  
end

function slice(boolvariate::CachedBoolVariate, fromobs::Integer, toobs::Integer, slicelength::Integer) 
    basevar = boolvariate.basevariate
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    if isa(basevar, CachedBoolVariate) || isa(basevar, BoolVariate)
        slice(basevar, fromobs, toobs, slicelength)
    else
        lockobj = boolvariate.lockobj
        lock(lockobj)
        try
            if !((fromobs, toobs) in keys(boolvariate.cache))
                v, _ = tryread(slice(basevar, fromobs, toobs, toobs - fromobs + 1))
                boolvariate.cache[(fromobs, toobs)] = get(v)
            end
        finally
            unlock(lockobj)
        end
        slice(boolvariate.cache[(fromobs, toobs)], 1, toobs - fromobs + 1, slicelength)
    end
end

function Base.map(boolvariate::CachedBoolVariate, dataframe::AbstractDataFrame)
    CachedBoolVariate(map(boolvariate.basevariate, dataframe))
end