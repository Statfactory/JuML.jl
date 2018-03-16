mutable struct CachedBoolVariate <: AbstractBoolVariate
    cache::Nullable{SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}}
    basevariate::AbstractBoolVariate
    lockobj::Threads.TatasLock
end

Base.length(var::CachedBoolVariate) = length(var.basevariate)

getname(var::CachedBoolVariate) = getname(var.basevariate)

function CachedBoolVariate(basevariate::AbstractBoolVariate) 
    CachedBoolVariate(Nullable{SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}}(), basevariate, Threads.TatasLock())  
end

function cache(basevariate::AbstractBoolVariate) 
    CachedBoolVariate(Nullable{SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}}(), basevariate, Threads.TatasLock())  
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
            if isnull(boolvariate.cache)
                v, _ = tryread(slice(basevar, 1, length(boolvariate), length(boolvariate)))
                boolvariate.cache = v
            end
        finally
            unlock(lockobj)
        end
        slice(get(boolvariate.cache), fromobs, toobs, slicelength)
    end
end

function Base.map(boolvariate::CachedBoolVariate, dataframe::AbstractDataFrame)
    CachedBoolVariate(map(boolvariate.basevariate, dataframe))
end