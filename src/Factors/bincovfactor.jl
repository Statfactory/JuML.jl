struct BinCovFactor{T<:Unsigned} <: AbstractFactor{T}
    name::String
    levels::AbstractVector{<:AbstractString}
    bins::AbstractVector{<:Real}
    covariate::AbstractCovariate{<:AbstractFloat}
end

Base.length(var::BinCovFactor{T}) where {T<:Unsigned} = length(var.covariate)

function BinCovFactor(name::String, bins::AbstractVector{T}, covariate::AbstractCovariate{S}) where {T<:Real} where {S<:AbstractFloat}
    bins = issorted(bins) ? bins : sort(bins)
    levelcount = length(bins) - 1
    levels = [@sprintf("[%G,%G%s", bins[i], bins[i + 1], i == levelcount ? "]" : ")") for i in 1:levelcount]
    if levelcount <= typemax(UInt8)
        BinCovFactor{UInt8}(name, levels, bins, covariate)
    elseif levelcount <= typemax(UInt16)
        BinCovFactor{UInt16}(name, levels, bins, covariate)
    else
        BinCovFactor{UInt32}(name, levels, bins, covariate)
    end
end

function factor(covariate::AbstractCovariate{S}, bins::AbstractVector{T}) where {T<:Real} where {S<:AbstractFloat}
    BinCovFactor(getname(covariate), bins, covariate)
end

function factor(covariate::AbstractCovariate{S}) where {S<:AbstractFloat}
    fromobs = 1
    toobs = length(covariate)
    slicelength = verifyslicelength(fromobs, toobs, SLICELENGTH)
    slices = slice(covariate, fromobs, toobs, slicelength)
    vset = fold(Set{S}(), slices) do acc, slice
        for i in 1:length(slice)
            v = slice[i]
            if !isnan(v)
                push!(acc, v)
            end
        end
        acc
    end
    bins = collect(vset)
    sort!(bins)
    BinCovFactor(getname(covariate), bins, covariate)
end

function factor(covariate::GroupStatsCovariate{N, U, Int64, T}) where {T<:AbstractFloat} where {N} where {U}
    if covariate.transform == identity
        bins = unique(collect(values(covariate.groupstats.stats)))
        BinCovFactor(getname(covariate), bins, covariate)
    else
        fromobs = 1
        toobs = length(covariate)
        slicelength = verifyslicelength(fromobs, toobs, SLICELENGTH)
        slices = slice(covariate, fromobs, toobs, slicelength)
        vset = fold(Set{S}(), slices) do acc, slice
            for i in 1:length(slice)
                v = slice[i]
                if !isnan(v)
                    push!(acc, v)
                end
            end
            acc
        end
        bins = collect(vset)
        sort!(bins)
        BinCovFactor(getname(covariate), bins, covariate)
    end
end

function slice(factor::BinCovFactor{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned}
    bins = factor.bins
    binlenm1 = convert(T, length(bins) - 1)
    z = bins[length(bins)]
    f = (x -> 
            begin
                if x == z 
                    return binlenm1
                elseif x > z || isnan(x)
                    return zero(T)
                else
                    i = searchsortedlast(bins, x)
                    return convert(T, i)
                end
            end
        )
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = slice(factor.covariate, fromobs, toobs, slicelength)
    mapslice(f, slices, slicelength, T)
end

function Base.map(factor::BinCovFactor{T}, dataframe::AbstractDataFrame; permute::Bool = false) where {T<:Unsigned}
    BinCovFactor(getname(factor), factor.bins, map(factor.covariate, dataframe))
end

function isordinal(factor::BinCovFactor{T}) where {T<:Unsigned}
    true
end