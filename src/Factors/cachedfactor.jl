struct CachedFactor{T<:Unsigned} <: AbstractFactor{T}
    cache::Dict{Tuple{Int64, Int64}, Vector{T}}
    basefactor::AbstractFactor{T}
end

Base.length(var::CachedFactor) = length(var.basefactor)

getname(var::CachedFactor) = getname(var.basefactor)

function CachedFactor(basefactor::AbstractFactor{T}) where {T<:Unsigned}
    CachedFactor{T}(Dict{Int64, Vector{T}}(), basefactor)   
end

function slice(factor::CachedFactor{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned}
    basefactor = factor.basefactor
    if isa(basefactor, CachedFactor) || isa(basefactor, Factor)
        slice(basefactor, fromobs, toobs, slicelength)
    else
        if (Int64(fromobs), Int64(toobs)) in keys(factor.cache)
            slice(factor.cache[(Int64(fromobs), Int64(toobs))], 1, toobs - fromobs + 1, slicelength)
        else
            v, _ = tryread(slice(basefactor, fromobs, toobs, toobs - fromobs + 1))
            factor.cache[(Int64(fromobs), Int64(toobs))] = get(v)
            slice(factor.cache[(Int64(fromobs), Int64(toobs))], 1, toobs - fromobs + 1, slicelength)
        end
    end
end

function Base.map(factor::CachedFactor, dataframe::AbstractDataFrame)
    CachedFactor(map(factor.basefactor, dataframe))
end