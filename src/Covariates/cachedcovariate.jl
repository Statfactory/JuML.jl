struct CachedCovariate{T<:AbstractFloat} <: AbstractCovariate{T}
    cache::Dict{Tuple{Int64, Int64}, Vector{T}}
    basecovariate::AbstractCovariate{T}
end

Base.length(var::CachedCovariate) = length(var.basecovariate)

getname(var::CachedCovariate) = getname(var.basecovariate)

function CachedCovariate(basecovariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    CachedCovariate{T}(Dict{Int64, Vector{T}}(), basecovariate)  
end

function slice(covariate::CachedCovariate{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat}
    basecov = covariate.basecovariate
    if isa(basecov, CachedCovariate) || isa(basecov, Covariate)
        slice(basecov, fromobs, toobs, slicelength)
    else
        if (Int64(fromobs), Int64(toobs)) in keys(covariate.cache)
            slice(covariate.cache[(Int64(fromobs), Int64(toobs))], 1, toobs - fromobs + 1, slicelength)
        else
            v, _ = tryread(slice(basecov, fromobs, toobs, toobs - fromobs + 1))
            covariate.cache[(Int64(fromobs), Int64(toobs))] = get(v)
            slice(covariate.cache[(Int64(fromobs), Int64(toobs))], 1, toobs - fromobs + 1, slicelength)
        end
    end
end

function Base.map(covariate::CachedCovariate, dataframe::AbstractDataFrame)
    CachedCovariate(map(covariate.basecovariate, dataframe))
end