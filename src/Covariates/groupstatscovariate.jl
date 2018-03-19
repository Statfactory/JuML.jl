mutable struct GroupStatsCovariate{T<:AbstractFloat} <: AbstractCovariate{T}
    name::String
    length::Int64
    groupstats::GroupStats
    transform::Function
end

function GroupStatsCovariate(name::String, groupstats::GroupStats, transform::Function)
    GroupStatsCovariate{Float32}(name, length(groupstats.covariate),  groupstats, transform)
end

function GroupStatsCovariate(::Type{T}, name::String, groupstats::GroupStats, transform::Function) where {T<:AbstractFloat}
    GroupStatsCovariate{T}(name, length(groupstats.covariate), groupstats, transform)
end

function slice(covariate::GroupStatsCovariate{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat}
    factors = widenfactors(covariate.groupstats.factors)
    dims = Tuple([length(getlevels(factor)) + 1 for factor in factors])
    k = length(factors)
    f = covariate.transform
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    factorslices = zipn([slice(factor, fromobs, toobs, slicelength) for factor in factors])
    groupstats = covariate.groupstats
    subindexmap = covariate.groupstats.subindexmap

    subind = Vector{Int64}(k)
    buffer = Vector{T}(slicelength)
    nanstats = CovariateStats(0, 0, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64)
    map(factorslices, SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}) do slicevector
       len = length(slicevector[1])
       for i in 1:len
           for j in 1:k
               subind[j] = slicevector[j][i]
               if subind[j] > 0
                   mappedindex = subindexmap[j][subind[j]]
                   subind[j] = mappedindex == 0 ? 0 : mappedindex + 1
                else
                    subind[j] = 1
               end
           end
           if findfirst(subind, 0) > 0
               buffer[i] = convert(T, f(nanstats))
           else
                ind = sub2ind(dims, subind...)
                mappedind = get(groupstats.linindexmap, ind, 0)
                if mappedind > 0
                    buffer[i] = convert(T, f(groupstats.stats[mappedind][2]))
                else
                    buffer[i] = convert(T, f(nanstats))
                end
           end
       end
       view(buffer, 1:len)
    end
end

function Base.map(cov::GroupStatsCovariate{T}, dataframe::AbstractDataFrame) where {T<:AbstractFloat}
    GroupStatsCovariate{T}(cov.name, length(dataframe), map(cov.groupstats, dataframe), cov.transform)
end