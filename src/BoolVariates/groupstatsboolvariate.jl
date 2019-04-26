mutable struct GroupStatsBoolVariate <:AbstractBoolVariate
    name::String
    length::Int64
    groupstats::GroupStats
    transform::Function
end

function slice(boolvar::GroupStatsBoolVariate, fromobs::Integer, toobs::Integer, slicelength::Integer) 
    factors = boolvar.groupstats.factors
    dims = Tuple(boolvar.groupstats.dims) #Tuple([length(getlevels(factor)) + 1 for factor in factors])
    k = length(factors)
    f = boolvar.transform
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    factorslices = zip([slice(factor, fromobs, toobs, slicelength) for factor in factors])
    groupstats = boolvar.groupstats
    subindexmap = covariate.groupstats.subindexmap

    subind = Vector{Int64}(undef, k)
    buffer = BitArray{1}(undef, slicelength)
    nanstats = CovariateStats(0, 0, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64)
    map(factorslices, Bool) do slicevector
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
               buffer[i] = f(nanstats)
           else
                ind = sub2ind(dims, subind...)
                mappedind = get(groupstats.linindexmap, ind, 0)
                if mappedind > 0
                    buffer[i] = f(groupstats.stats[mappedind][2])
                else
                    buffer[i] = f(nanstats)
                end
           end
       end
       view(buffer, 1:len)
    end
end

function Base.map(boolvariate::GroupStatsBoolVariate, dataframe::AbstractDataFrame)
    GroupStatsBoolVariate(boolvariate.name, length(dataframe), map(boolvariate.groupstats, dataframe), boolvariate.transform)
end