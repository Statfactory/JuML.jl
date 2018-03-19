struct GroupStats
    factors::Vector{<:AbstractFactor}
    covariate::AbstractCovariate
    stats::Vector{Tuple{String, CovariateStats}}
    linindexmap::Dict{Int64, Int64}
    subindexmap::Vector{Vector{Int64}}
end

function Base.getindex(gstats::GroupStats, index::Integer)
    gstats.stats[index]
end

function getstats(factors::Vector{<:AbstractFactor}, covariate::AbstractCovariate; slicelength::Integer = SLICELENGTH)
    levels = [getlevels(factor) for factor in factors]
    factors = widenfactors(factors)
    dims = Tuple([length(getlevels(factor)) + 1 for factor in factors])
    k = length(factors)
    obscount = length(covariate)
    factorslices = zipn([slice(factor, 1, obscount, slicelength) for factor in factors])
    covslices = slice(covariate,  1, obscount, slicelength)
    subindexmap = [collect(1:length(getlevels(f))) for f in factors]
    initstats = Vector{Tuple{String, CovariateStats}}()
    initlinindexmap = Dict{Int64, Int64}()
    subind = Vector{Int64}(k)
    resstats, reslinindexmap = fold((initstats, initlinindexmap), zip2(factorslices, covslices)) do acc, slices
        stats, linindexmap = acc
        factorslicevector, covslice = slices
        len = length(factorslicevector[1])
        for i in 1:len
            for j in 1:k
                subind[j] = factorslicevector[j][i] + 1
            end
            ind = sub2ind(dims, subind...)
            mappedind = get(linindexmap, ind, 0)
            if mappedind == 0 
                level = join(map((x -> x[2] == 1 ? MISSINGLEVEL : levels[x[1]][x[2] - 1]), enumerate(subind)), "*")
                push!(stats, (level, CovariateStats(0, 0, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64)))
                mappedind = length(stats)
                linindexmap[ind] = mappedind
            end
            v = covslice[i]
            _, s = stats[mappedind]
            s.obscount += 1
            if isnan(v)
                s.nancount += 1
            else
                if isnan(s.sum)
                    s.sum = v
                    s.sum2 = v * v
                    s.min = v
                    s.max = v
                else
                    s.sum += v
                    s.sum2 += v * v
                    if v < s.min
                        s.min = v
                    end
                    if v > s.max
                        s.max = v
                    end
                end
            end
        end
        stats, linindexmap
    end
    for (_, stats) in resstats
        stats.nanpcnt = 100.0 * stats.nancount / stats.obscount
        stats.mean = stats.sum / (stats.obscount - stats.nancount)
        stats.std = sqrt(((stats.sum2 - stats.sum * stats.sum / (stats.obscount - stats.nancount)) / (stats.obscount - stats.nancount - 1)))
    end
    GroupStats(factors, covariate, resstats, reslinindexmap, subindexmap)
end

function Base.map(groupstats::GroupStats, dataframe::AbstractDataFrame)
    factors = groupstats.factors
    mappedfactors = map(factors) do f
        map(f, dataframe)
    end
    maplevels = (levels, basefactor) -> begin
        baselevels = getlevels(basefactor)
        [findfirst(baselevels, level) for level in levels]
    end
    subindexmap = [maplevels(getlevels(f), factors[i]) for (i, f) in enumerate(mappedfactors)]
    GroupStats(factors, groupstats.covariate, groupstats.stats, groupstats.linindexmap, subindexmap)
end