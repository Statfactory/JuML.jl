mutable struct CachedBoolVariate <: AbstractBoolVariate
    cache::Nullable{BitArray{1}}
    basevariate::AbstractBoolVariate
    lockobj::Threads.TatasLock
end

Base.length(var::CachedBoolVariate) = length(var.basevariate)

getname(var::CachedBoolVariate) = getname(var.basevariate)

function CachedBoolVariate(basevariate::AbstractBoolVariate) 
    CachedBoolVariate(Nullable{BitArray{1}}(), basevariate, Threads.TatasLock())  
end

function cache(basevariate::AbstractBoolVariate) 
    CachedBoolVariate(Nullable{BitArray{1}}(), basevariate, Threads.TatasLock())  
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
                slices = slice(basevar, 1, length(basevar), SLICELENGTH)
                cachedata = BitArray{1}(length(basevar))
                fold(0, slices) do offset, slice
                    n = length(slice)
                    @inbounds for i in 1:n
                        cachedata[i + offset] = slice[i]
                    end
                    offset += n
                end
                boolvariate.cache = Nullable{ BitArray{1}}(cachedata)
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