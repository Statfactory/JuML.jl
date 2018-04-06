struct GroupStats{N} 
    keyvars::NTuple{N, StatVariate}
    covariate::Nullable{AbstractCovariate}
    stats::Dict
end

function getgroupstats(factor1::AbstractFactor{S}, factor2::AbstractFactor{T}; slicelength::Integer = SLICELENGTH) where {S<:Unsigned} where {T<:Unsigned}
    fromobs = 1
    toobs = length(factor1)
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = zip2(slice(factor1, fromobs, toobs, slicelength), slice(factor2, fromobs, toobs, slicelength))
    dict = fold(Dict{Tuple{S, T}, Int64}(), slices) do d, slice
        slice1::SubArray{S,1,Array{S,1},Tuple{UnitRange{Int64}},true}, slice2::SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true} = slice
        @inbounds for i in 1:length(slice1)
            v = slice1[i], slice2[i]
            d[v] = get(d, v, 0) + 1
        end
        d
    end
    GroupStats{2}((factor1, factor2), Nullable(), dict)
end

function getgroupstats(statvars::NTuple{N, StatVariate}; slicelength::Integer = SLICELENGTH) where {N}
    eltypes = map((s -> eltype(s)), statvars)
    dict = Dict{Tuple{eltypes...}, Int64}()
    fromobs = 1
    toobs = length(statvars[1])
    slicelength = verifyslicelength(fromobs, toobs, slicelength)  
    slices = zipn(map((s -> slice(s, fromobs, toobs, slicelength)), statvars))
    dict = fold(Dict{Tuple{eltypes...}, Int64}(), slices) do d, slice
        if N == 2
            slice1, slice2 = slice
            for i in 1:length(slice1)
                v = slice1[i], slice2[i]
                d[v] = get(d, v, 0) + 1
            end
        elseif N == 3
            slice1, slice2, slice3 = slice
            for i in 1:length(slice1)
                v = slice1[i], slice2[i], slice3[i]
                d[v] = get(d, v, 0) + 1
            end
        else
            for i in 1:length(slice[1])
                v = map((x -> x[i]), slice)
                d[v] = get(d, v, 0) + 1
            end
        end
        d
    end
    GroupStats{N}(statvars, Nullable(), dict)
end

function getgroupstats(statvar::StatVariate; slicelength::Integer = SLICELENGTH)
    statvars = (statvar, )
    getgroupstats(statvars; slicelength = slicelength) 
end

function getgroupstats(statvars::NTuple{N, StatVariate}, cov::AbstractCovariate{S}; slicelength::Integer = SLICELENGTH) where {N} where {S<:AbstractFloat}
    eltypes = map((s -> eltype(s)), statvars)
    dict = Dict{Tuple{eltypes...}, CovariateStats}()
    fromobs = 1
    toobs = length(statvars[1])
    slicelength = verifyslicelength(fromobs, toobs, slicelength)  
    slices = zip(map((s -> slice(s, fromobs, toobs, slicelength)), statvars))
    covslices = slice(cov, fromobs, toobs, slicelength)
    zipslices = zip2(slices, covslices)
    fold(dict, zipslices) do d, zipslice
        slice, covslice = zipslice
        for i in 1:length(slice[1])
            x = map((x -> x[i]), slice)
            v = covslice[i]
            if !(x in keys(d))
                covstats = CovariateStats(0, 0, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64)
                d[x] = covstats
            else
                covstats = d[x]
            end
            covstats.obscount += 1
            if isnan(v)
                covstats.nancount += 1
            else
                if isnan(covstats.sum)
                    covstats.sum = v
                    covstats.sum2 = v * v
                    covstats.min = v
                    covstats.max = v
                else
                    covstats.sum += v
                    covstats.sum2 += v * v
                    if v < covstats.min
                        covstats.min = v
                    end
                    if v > covstats.max
                        covstats.max = v
                    end
                end
            end
        end
        d
    end
    for (_, stats) in dict
        stats.nanpcnt = 100.0 * stats.nancount / stats.obscount
        stats.mean = stats.sum / (stats.obscount - stats.nancount)
        stats.std = sqrt(((stats.sum2 - stats.sum * stats.sum / (stats.obscount - stats.nancount)) / (stats.obscount - stats.nancount - 1)))
    end
    GroupStats{N}(statvars, Nullable(cov), dict)
end

function getgroupstats(statvar::StatVariate, cov::AbstractCovariate{S}; slicelength::Integer = SLICELENGTH) where {S<:AbstractFloat}
    statvars = (statvar, )
    getgroupstats(statvars, cov; slicelength = slicelength) 
end
