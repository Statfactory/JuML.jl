mutable struct CachedBoolVariate <: AbstractBoolVariate
    cache::Union{BitArray{1}, Nothing}
    basevariate::AbstractBoolVariate
    lockobj::Threads.TatasLock
end

Base.length(var::CachedBoolVariate) = length(var.basevariate)

getname(var::CachedBoolVariate) = getname(var.basevariate)

function CachedBoolVariate(basevariate::AbstractBoolVariate) 
    CachedBoolVariate(nothing, basevariate, Threads.TatasLock())  
end

function cache(basevariate::AbstractBoolVariate) 
    CachedBoolVariate(nothing, basevariate, Threads.TatasLock())  
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
            if boolvariate.cache === nothing
                slices = slice(basevar, 1, length(basevar), SLICELENGTH)
                cachedata = BitArray{1}(undef, length(basevar))
                fold(0, slices) do offset, slice
                    n = length(slice)
                    view(cachedata, (1 + offset):(n + offset)) .= slice
                    offset += n
                end
                boolvariate.cache = cachedata
            end
        finally
            unlock(lockobj)
        end
        slice(boolvariate.cache, fromobs, toobs, slicelength)
    end
end

function Base.map(boolvariate::CachedBoolVariate, dataframe::AbstractDataFrame)
    CachedBoolVariate(map(boolvariate.basevariate, dataframe))
end