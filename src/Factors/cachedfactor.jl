mutable struct CachedFactor{T<:Unsigned} <: AbstractFactor{T}
    cache::Dict{Tuple{Int64, Int64}, SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}}
    basefactor::AbstractFactor{T}
    lockobj::Threads.TatasLock
end

Base.length(var::CachedFactor) = length(var.basefactor)

getname(var::CachedFactor) = getname(var.basefactor)

getlevels(var::CachedFactor) = getlevels(var.basefactor)

function CachedFactor(factor::AbstractFactor{T}) where {T<:Unsigned}
    if isa(factor, WiderFactor{T, T})
        CachedFactor{T}(Dict{Tuple{Int64, Int64}, SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}}(), factor.basefactor, Threads.TatasLock()) 
    else
        CachedFactor{T}(Dict{Tuple{Int64, Int64}, SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}}(), factor, Threads.TatasLock()) 
    end
end

function cache(basefactor::AbstractFactor{T}) where {T<:Unsigned}
    CachedFactor{T}(Dict{Tuple{Int64, Int64}, SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}}(), basefactor, Threads.TatasLock()) 
end

function slice(factor::CachedFactor{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned}
    basefactor = factor.basefactor
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    if isa(basefactor, CachedFactor) || isa(basefactor, Factor)
        slice(basefactor, fromobs, toobs, slicelength)
    else
        lockobj = factor.lockobj
        lock(lockobj)
        try
            if !((fromobs, toobs) in keys(factor.cache))
                v, _ = tryread(slice(basefactor, fromobs, toobs, toobs - fromobs + 1))
                factor.cache[(fromobs, toobs)] = get(v)
            end
        finally
            unlock(lockobj)
        end
        slice(factor.cache[(fromobs, toobs)], 1, toobs - fromobs + 1, slicelength)
    end
end

function Base.map(factor::CachedFactor{T}, dataframe::AbstractDataFrame) where {T<:Unsigned}
    CachedFactor(map(factor.basefactor, dataframe))
end

function isordinal(factor::CachedFactor{T}) where {T<:Unsigned}
    isordinal(factor.basefactor)
end