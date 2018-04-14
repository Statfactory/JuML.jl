struct BinDateTimeFactor{T<:Unsigned} <: AbstractFactor{T}
    name::String
    levels::AbstractVector{<:AbstractString}
    bins::AbstractVector{Int64}
    datetimevariate::AbstractDateTimeVariate
end

Base.length(var::BinDateTimeFactor{T}) where {T<:Unsigned} = length(var.datetimevariate)

function BinDateTimeFactor(name::String, bins::AbstractVector{Int64}, dtvariate::AbstractDateTimeVariate)
    bins = issorted(bins) ? bins : sort(bins)
    levelcount = length(bins) - 1
    levels = [@sprintf("[%s,%s%s", string(Dates.epochms2datetime(bins[i])), string(Dates.epochms2datetime(bins[i + 1])), i == levelcount ? "]" : ")") for i in 1:levelcount]
    if levelcount <= typemax(UInt8)
        BinDateTimeFactor{UInt8}(name, levels, bins, dtvariate)
    elseif levelcount <= typemax(UInt16)
        BinDateTimeFactor{UInt16}(name, levels, bins, dtvariate)
    else
        BinDateTimeFactor{UInt32}(name, levels, bins, dtvariate)
    end
end

function factor(dtvariate::AbstractDateTimeVariate, bins::AbstractVector{Int64}) 
    BinDateTimeFactor(getname(dtvariate), bins, dtvariate)
end

function factor(dtvariate::AbstractDateTimeVariate) 
    fromobs = 1
    toobs = length(dtvariate)
    slicelength = verifyslicelength(fromobs, toobs, SLICELENGTH)
    slices = slice(dtvariate, fromobs, toobs, slicelength)
    vset = fold(Set{Int64}(), slices) do acc, slice
        for i in 1:length(slice)
            v = slice[i]
            push!(acc, v)
        end
        acc
    end
    bins = collect(vset)
    sort!(bins)
    BinDateTimeFactor(getname(dtvariate), bins, dtvariate)
end

function slice(factor::BinDateTimeFactor{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned}
    bins = factor.bins
    binlenm1 = convert(T, length(bins) - 1)
    z = bins[length(bins)]
    f = (x -> 
            begin
                if x == z
                    return binlenm1
                elseif x > z || x == zero(Int64)
                    return zero(T)
                else
                    i = searchsortedlast(bins, x)
                    return convert(T, i)
                end
            end
        )
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = slice(factor.datetimevariate, fromobs, toobs, slicelength)
    mapslice(f, slices, slicelength, T)
end

function Base.map(factor::BinDateTimeFactor{T}, dataframe::AbstractDataFrame) where {T<:Unsigned}
    BinDateTimeFactor(getname(factor), factor.bins, map(factor.datetimevariate, dataframe))
end

function isordinal(factor::BinDateTimeFactor{T}) where {T<:Unsigned}
    true
end
