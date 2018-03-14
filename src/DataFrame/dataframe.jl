import JSON

abstract type AbstractDataFrame end

abstract type StatVariate end

abstract type AbstractFactor{T<:Unsigned} <: StatVariate end

abstract type AbstractCovariate{T<:AbstractFloat} <: StatVariate end

abstract type AbstractBoolVariate <: StatVariate end

abstract type AbstractDateTimeVariate <: StatVariate end

struct DataFrame <: AbstractDataFrame
    length::Int64
    factors::AbstractVector{<:AbstractFactor}
    covariates::AbstractVector{<:AbstractCovariate}
    boolvariates::AbstractVector{<:AbstractBoolVariate}
    datetimevariates::AbstractVector{<:AbstractDateTimeVariate}
end

mutable struct CovariateStats
    obscount::Int64
    nancount::Int64
    nanpcnt::Float64
    sum::Float64
    sum2::Float64
    mean::Float64
    std::Float64
    min::Float64
    max::Float64
end

mutable struct DateTimeVariateStats
    obscount::Int64
    nancount::Int64
    nanpcnt::Float64
    min::Int64
    max::Int64
end

mutable struct LevelStats
    level::String
    freq::Int64
    freqpcnt::Float64
end

mutable struct FactorStats
    obscount::Int64
    missingfreq::Int64
    missingpcnt::Float64
    levelstats::Vector{LevelStats}
end

function Base.length(dataframe::AbstractDataFrame)
    dataframe.length
end

getlevels(factor::AbstractFactor{T}) where {T<:Unsigned} = factor.levels

getname(factor::AbstractFactor{T}) where {T<:Unsigned} = factor.name

getname(covariate::AbstractCovariate{T}) where {T<:AbstractFloat} = covariate.name

getname(boolvar::AbstractBoolVariate) = boolvar.name

getname(datetimevar::AbstractDateTimeVariate) = datetimevar.name

function widenfactors(factors::Vector{<:AbstractFactor})
    if all(map((factor -> issubtype(typeof(factor), AbstractFactor{UInt8})), factors))
        factors
    elseif all(map((factor -> issubtype(typeof(factor), AbstractFactor{UInt16})), factors))
            factors
    elseif all(map((factor -> issubtype(typeof(factor), AbstractFactor{UInt32})), factors))
            factors
    elseif all(map((factor -> issubtype(typeof(factor), AbstractFactor{UInt8}) || issubtype(typeof(factor), AbstractFactor{UInt16})), factors))
        [issubtype(typeof(factor), AbstractFactor{UInt16}) ? factor : WiderFactor{UInt8, UInt16}(factor) for factor in factors]
    else
        [issubtype(typeof(factor), AbstractFactor{UInt32}) ? factor : (issubtype(typeof(factor), AbstractFactor{UInt16}) ? WiderFactor{UInt16, UInt32}(factor) : WiderFactor{UInt8, UInt32}(factor)) for factor in factors]
    end
end

function DataFrame(path::String; preload::Bool = true)
    path = abspath(path)
    headerpath = isfile(path) ? path : joinpath(path, "header.txt")
    headerjson = open(headerpath) do f 
        readstring(f)
    end
    header = JSON.parse(headerjson)
    factors = Vector{AbstractFactor}()
    covariates = Vector{AbstractCovariate}()
    dtvariates = Vector{AbstractDateTimeVariate}()
    datacols = header["datacolumns"]
    len = 0
    for datacol in datacols
        datatype = datacol["datatype"]
        len = datacol["length"]
        name = datacol["name"]
        datpath = joinpath(dirname(headerpath), datacol["filename"])

        if datatype == "Float32"
            if preload
                push!(covariates, Covariate{Float32}(name, len, datpath))
            else
                push!(covariates, FileCovariate{Float32}(name, len, datpath))
            end
        end

        if datatype == "DateTime"
            if preload
                push!(dtvariates, DateTimeVariate(name, len, datpath))
            else
                push!(dtvariates, FileDateTimeVariate(name, len, datpath))
            end
        end

        if datatype == "UInt8"
            levels = [string(level) for level in datacol["levels"]]
            if length(levels) == 0
                levels = Vector{String}()
            end
            if preload
                push!(factors, Factor{UInt8}(name, len, levels, datpath)) 
            else
                push!(factors, FileFactor{UInt8}(name, len, levels, datpath)) 
            end
        end

        if datatype == "UInt16"
            levels = [string(level) for level in datacol["levels"]]
            if length(levels) == 0
                levels = Vector{String}()
            end
            if preload
                push!(factors, Factor{UInt16}(name, len, levels, datpath))  
            else
                push!(factors, FileFactor{UInt16}(name, len, levels, datpath))   
            end
        end

        if datatype == "UInt32"
            levels = [string(level) for level in datacol["levels"]]
            if length(levels) == 0
                levels = Vector{String}()
            end
            if preload
                push!(factors, Factor{UInt32}(name, len, levels, datpath))  
            else
                push!(factors, FileFactor{UInt32}(name, len, levels, datpath))   
            end       
        end
    end
    DataFrame(len, factors, covariates, AbstractBoolVariate[], dtvariates)
end

function Base.getindex(df::AbstractDataFrame, name::String)
    for factor in df.factors
        if getname(factor) == name
            return factor
        end
    end
    for cov in df.covariates
        if getname(cov) == name
            return cov
        end
    end
    for dt in df.datetimevariates
        if getname(dt) == name
            return dt
        end
    end
end

function Base.summary(factor::AbstractFactor{T}) where {T<:Unsigned}
    io = IOBuffer()
    factorstats = getstats(factor)
    println(io, @sprintf("%-16s%15d", "Obs Count", factorstats.obscount))
    println(io, @sprintf("%-16s%15s%15s", "Level", "Frequency", "Frequency(%)"))
    println(io, @sprintf("%-16s%15d%15G", MISSINGLEVEL, factorstats.missingfreq, factorstats.missingpcnt))
    for levelstats in factorstats.levelstats
        println(io, @sprintf("%-16s%15d%15G", levelstats.level, levelstats.freq, levelstats.freqpcnt))
    end
    print(String(take!(io)))
end

function Base.summary(boolvar::AbstractBoolVariate)
    io = IOBuffer()
    len = length(boolvar)
    slices = slice(boolvar, 1, len, SLICELENGTH)
    truefreq = fold(0, slices) do acc, slice
        res = acc
        for v in slice
            if v    
                res += 1
            end
        end
        res
    end
    println(io, @sprintf("%-15s%12d", "Obs Count", len))
    println(io, @sprintf("%-15s%12d", "True Freq", truefreq))
    println(io, @sprintf("%-15s%12G", "True Freq (%)", 100.0 * truefreq / len))
    print(String(take!(io)))
end

function getstats(factor::AbstractFactor{T}) where {T<:Unsigned}
    len = length(factor)
    levels = getlevels(factor)
    levelcount = length(levels)
    init = zeros(Int64, levelcount + 1)
    slices = slice(factor, 1, len, SLICELENGTH)
    freq = fold(init, slices) do frq, slice
        for levelindex in slice
            frq[levelindex + 1] += 1 
        end
        frq
    end
    missingfreq = freq[1]
    missingpcnt = 100.0 * missingfreq / len
    levelstats = [LevelStats(levels[i], freq[i + 1], 100.0 * freq[i + 1] / len) for i in 1:levelcount]  
    FactorStats(len, missingfreq, missingpcnt, levelstats)
end

function getstats(covariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    len = length(covariate)
    init = CovariateStats(0, 0, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64)
    slices = slice(covariate, 1, len, SLICELENGTH)
    stats = fold(init, slices) do s, slice
        for v in slice
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
        s
    end
    stats.obscount = len
    stats.nanpcnt = 100.0 * stats.nancount / len
    stats.mean = stats.sum / (len - stats.nancount)
    stats.std = sqrt(((stats.sum2 - stats.sum * stats.sum / (len - stats.nancount)) / (len - stats.nancount - 1)))
    stats
end

function getstats(factor::AbstractFactor{T}, covariate::AbstractCovariate{S}) where {T<:Unsigned} where {S<:AbstractFloat}
    len = length(covariate)
    levelcount = length(getlevels(factor))
    levelsinit = [CovariateStats(0, 0, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64) for i in 1:levelcount]
    missinit = CovariateStats(0, 0, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64)
    covslices = slice(covariate, 1, len, SLICELENGTH)
    factorslices = slice(factor, 1, len, SLICELENGTH)
    zipslices = zip2(factorslices, covslices)
    missacc, levelacc = fold((missinit, levelsinit), zipslices) do acc, slice
        missstat, levelsstat = acc
        fslice, cslice = slice
        for (i, levelindex) in enumerate(fslice)
            v = cslice[i]
            if levelindex == zero(T)
                missstat.obscount += 1
                if isnan(v)
                    missstat.nancount += 1
                else
                    if isnan(missstat.sum)
                        missstat.sum = v
                        missstat.sum2 = v * v
                        missstat.min = v
                        missstat.max = v
                    else
                        missstat.sum += v
                        missstat.sum2 += v * v
                        if v < missstat.min
                            missstat.min = v
                        end
                        if v > missstat.max
                            missstat.max = v
                        end
                    end
                end
            else
                levelsstat[levelindex].obscount += 1
                if isnan(v)
                    levelsstat[levelindex].nancount += 1
                else
                    if isnan(levelsstat[levelindex].sum)
                        levelsstat[levelindex].sum = v
                        levelsstat[levelindex].sum2 = v * v
                        levelsstat[levelindex].min = v
                        levelsstat[levelindex].max = v
                    else
                        levelsstat[levelindex].sum += v
                        levelsstat[levelindex].sum2 += v * v
                        if v < levelsstat[levelindex].min
                            levelsstat[levelindex].min = v
                        end
                        if v > levelsstat[levelindex].max
                            levelsstat[levelindex].max = v
                        end
                    end
                end
            end
        end
        acc
    end
    missacc.nanpcnt = 100.0 * missacc.nancount / missacc.obscount
    missacc.mean = missacc.sum / (missacc.obscount - missacc.nancount)
    missacc.std = sqrt(((missacc.sum2 - missacc.sum * missacc.sum / (missacc.obscount - missacc.nancount)) / (missacc.obscount - missacc.nancount - 1)))
    for i in 1:levelcount
        levelacc[i].nanpcnt = 100.0 * levelacc[i].nancount / levelacc[i].obscount
        levelacc[i].mean = levelacc[i].sum / (levelacc[i].obscount - levelacc[i].nancount)
        levelacc[i].std = sqrt(((levelacc[i].sum2 - levelacc[i].sum * levelacc[i].sum / (levelacc[i].obscount - levelacc[i].nancount)) / (levelacc[i].obscount - levelacc[i].nancount - 1)))
    end
    missacc, levelacc
end

function getstats(dtvariate::AbstractDateTimeVariate) 
    len = length(dtvariate)
    init = DateTimeVariateStats(0, 0, NaN64, 0, 0)
    slices = slice(dtvariate, 1, len, SLICELENGTH)
    stats = fold(init, slices) do s, slice
        for v in slice
            if v == zero(Int64)
                s.nancount += 1
            else
                if s.min == zero(Int64)
                    s.min = v
                    s.max = v
                else
                    if v < s.min
                        s.min = v
                    end
                    if v > s.max
                        s.max = v
                    end
                end
            end
        end
        s
    end
    stats.obscount = len
    stats.nanpcnt = 100.0 * stats.nancount / len
    stats
end

function Base.summary(covariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    io = IOBuffer()
    stats = getstats(covariate)
    println(io, @sprintf("%-15s%12d", "Obs Count", stats.obscount))
    println(io, @sprintf("%-15s%12d", "NaN Freq", stats.nancount))
    println(io, @sprintf("%-15s%12G", "NaN %", stats.nanpcnt))
    println(io, @sprintf("%-15s%12G", "Min", stats.min))
    println(io, @sprintf("%-15s%12G", "Max", stats.max))
    println(io, @sprintf("%-15s%12G", "Mean", stats.mean))
    println(io, @sprintf("%-15s%12G", "Std", stats.std))
    print(String(take!(io)))
end

function Base.summary(dtvariate::AbstractDateTimeVariate) 
    io = IOBuffer()
    stats = getstats(dtvariate)
    println(io, @sprintf("%-15s%12d", "Obs Count", stats.obscount))
    println(io, @sprintf("%-15s%12d", "NaN Freq", stats.nancount))
    println(io, @sprintf("%-15s%12G", "NaN %", stats.nanpcnt))
    println(io, @sprintf("%-15s%12s", "Min", Dates.format(Dates.epochms2datetime(stats.min), "yyyy-mm-ddTHH:MM:SS")))
    println(io, @sprintf("%-15s%12s", "Max", Dates.format(Dates.epochms2datetime(stats.max), "yyyy-mm-ddTHH:MM:SS")))
    print(String(take!(io)))
end

function Base.show(io::IO, covariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    slices = slice(covariate, 1, HEADLENGTH, HEADLENGTH)
    slice1, _ = tryread(slices)
    len = length(covariate)
    if !isnull(slice1)
        datahead = join([isnan(v) ? "." : string(v) for v in get(slice1)], " ")
        dataend = len > HEADLENGTH ? "  ..." : ""
        println(io, "Covariate $(getname(covariate)) with $(len) obs: $(datahead)$dataend")
    else
        println(io, "Covariate $(getname(covariate)) with $(len) obs")
    end
end

function Base.show(io::IO, boolvar::AbstractBoolVariate) 
    slices = slice(boolvar, 1, HEADLENGTH, HEADLENGTH)
    slice1, _ = tryread(slices)
    len = length(boolvar)
    if !isnull(slice1)
        datahead = join([string(v) for v in get(slice1)], " ")
        dataend = len > HEADLENGTH ? "  ..." : ""
        println(io, "BoolVar $(getname(boolvar)) with $(len) obs: $(datahead)$dataend")
    else
        println(io, "BoolVar $(getname(boolvar)) with $(len) obs")
    end
end

function Base.show(io::IO, datetimevar::AbstractDateTimeVariate) 
    slices = slice(datetimevar, 1, HEADLENGTH, HEADLENGTH)
    slice1, _ = tryread(slices)
    len = length(datetimevar)
    if !isnull(slice1)
        datahead = join([v == zero(Int64) ? MISSINGLEVEL : string(Dates.epochms2datetime(v)) for v in get(slice1)], " ")
        dataend = len > HEADLENGTH ? "  ..." : ""
        println(io, "DateTimeVar $(getname(datetimevar)) with $(len) obs: $(datahead)$dataend")
    else
        println(io, "DateTimeVar $(getname(datetimevar)) with $(len) obs")
    end
end

function Base.show(io::IO, factor::AbstractFactor{T}) where {T<:Unsigned}
    slices = slice(factor, 1, HEADLENGTH, HEADLENGTH)
    slice1, _ = tryread(slices)
    len = length(factor)
    levels = getlevels(factor)
    levelcount = length(levels)
    if !isnull(slice1)
        datahead = join([index == 0 ? MISSINGLEVEL : levels[index] for index in get(slice1)], " ")
        dataend = len > HEADLENGTH ? "  ..." : ""
        println(io, "Factor $(getname(factor)) with $(len) obs and $(levelcount) levels: $(datahead)$dataend")
    else
        println(io, "Factor $(getname(factor)) with $(len) obs and $(levelcount) levels")
    end
end

function Base.convert(::Type{Vector{T}}, covariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    v, _ = tryread(slice(covariate, 1, length(covariate), length(covariate)))
    get(v)
end

function Base.convert(::Type{BitArray}, boolvariate::AbstractBoolVariate) 
    v, _ = tryread(slice(boolvariate, 1, length(boolvariate), length(boolvariate)))
    get(v)
end

function isordinal(factor::AbstractFactor{T}) where {T<:Unsigned}
    false
 end

function slicestring(factor::AbstractFactor{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned}
    slicelength = verifyslicelength(fromobs, toobs, slicelength)
    levels = getlevels(factor)
    f = (i::T) -> i == zero(T) ? "" : levels[i]
    slices = slice(factor, fromobs, toobs, slicelength)
    mapslice(f, slices, slicelength, String)
end

function slicestring(covariate::AbstractCovariate{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat}
    slicelength = verifyslicelength(fromobs, toobs, slicelength)
    f = (x::T) -> isnan(x) ? "" : (x == floor(x) ? @sprintf("%D", x) : @sprintf("%F", x))
    slices = slice(covariate, fromobs, toobs, slicelength)
    mapslice(f, slices, slicelength, String)
end

function tocsv(path::String, dataframe::AbstractDataFrame)
    path = abspath(path)
    iostream = open(path, "w")
    factors = dataframe.factors
    covariates = dataframe.covariates
    len = length(dataframe)
    fslices = [slicestring(f, 1, len, SLICELENGTH) for f in factors]
    covslices = [slicestring(c, 1, len, SLICELENGTH) for c in covariates]
    strslices = begin
        if length(factors) == 0
            zipn(covslices)
        elseif length(covariates) == 0
            zipn(fslices)
        else
            zipn([fslices; covslices])
        end
    end
    ncol = length(factors) + length(covariates)
    colnames = Vector{String}()
    foreach((f -> push!(colnames, getname(f))), factors) 
    foreach((c -> push!(colnames, getname(c))), covariates) 
    headersline = join(colnames, ",") * "\r\n"
    write(iostream, headersline)
    foreach(strslices) do x
        slicelen = length(x[1])
        for i in 1:slicelen
            line = join([x[j][i] for j in 1:ncol], ",") * "\r\n"
            write(iostream, line)
        end
    end
    close(iostream)
end

