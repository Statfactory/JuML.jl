mutable struct CachedFactor{T<:Unsigned} <: AbstractFactor{T}
    cache::Nullable{AbstractVector{T}}
    basefactor::AbstractFactor{T}
    lockobj::Threads.TatasLock
end

Base.length(var::CachedFactor) = length(var.basefactor)

getname(var::CachedFactor) = getname(var.basefactor)

getlevels(var::CachedFactor) = getlevels(var.basefactor)

function CachedFactor(basefactor::AbstractFactor{T}) where {T<:Unsigned}
    CachedFactor{T}(Nullable{AbstractVector{T}}(), basefactor, Threads.TatasLock())   
end

function cache(basefactor::AbstractFactor{T}) where {T<:Unsigned}
    CachedFactor{T}(Nullable{AbstractVector{T}}(), basefactor, Threads.TatasLock()) 
end

function slice(factor::CachedFactor{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned}
    basefactor = factor.basefactor
    if isa(basefactor, CachedFactor) || isa(basefactor, Factor)
        slice(basefactor, fromobs, toobs, slicelength)
    else
        lockobj = factor.lockobj
        lock(lockobj)
        try
            if isnull(factor.cache)
                v, _ = tryread(slice(basefactor, 1, length(basefactor), length(basefactor)))
                factor.cache = v
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