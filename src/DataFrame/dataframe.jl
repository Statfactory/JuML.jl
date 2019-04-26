import JSON
using Printf

abstract type AbstractDataFrame end

abstract type StatVariate end

abstract type AbstractFactor{T<:Unsigned} <: StatVariate end

abstract type AbstractCovariate{T<:AbstractFloat} <: StatVariate end

abstract type AbstractBoolVariate <: StatVariate end

abstract type AbstractDateTimeVariate <: StatVariate end

abstract type AbstractIntVariate{T<:Signed} <: StatVariate end

struct DataFrame <: AbstractDataFrame
    length::Int64
    factors::AbstractVector{<:AbstractFactor}
    covariates::AbstractVector{<:AbstractCovariate}
    boolvariates::AbstractVector{<:AbstractBoolVariate}
    datetimevariates::AbstractVector{<:AbstractDateTimeVariate}
    intvariates::AbstractVector{<:AbstractIntVariate}
    headerpath::String
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

getname(intvariate::AbstractIntVariate{T}) where {T<:Signed} = intvariate.name

getname(boolvar::AbstractBoolVariate) = boolvar.name

getname(datetimevar::AbstractDateTimeVariate) = datetimevar.name

Base.length(covariate::AbstractCovariate{T}) where {T<:AbstractFloat} = covariate.length

Base.length(intvariate::AbstractIntVariate{T}) where {T<:Signed} = intvariate.length

Base.length(boolvar::AbstractBoolVariate) = boolvar.length

Base.length(factor::AbstractFactor{T}) where {T<:Unsigned} = factor.length

function DataFrame(path::String; preload::Bool = true)
    path = abspath(path)
    headerpath = isfile(path) ? path : joinpath(path, "header.txt")
    headerjson = open(headerpath) do f 
        read(f, String)
    end
    header = JSON.parse(headerjson)
    factors = Vector{AbstractFactor}()
    covariates = Vector{AbstractCovariate}()
    dtvariates = Vector{AbstractDateTimeVariate}()
    intvariates = Vector{AbstractIntVariate}()
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

        if datatype == "Int64"
            if preload
                push!(intvariates, IntVariate{Int64}(name, len, datpath))
            else
                push!(intvariates, FileIntVariate{Int64}(name, len, datpath))
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
    DataFrame(len, factors, covariates, AbstractBoolVariate[], dtvariates, intvariates, headerpath)
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

    for ivar in df.intvariates
        if getname(ivar) == name
            return ivar
        end
    end
end

function Base.summary(factor::AbstractFactor{T}; selector::AbstractBoolVariate = BoolVariate("", BitArray{1}())) where {T<:Unsigned}
    io = IOBuffer()
    factorstats = getstats(factor; selector = selector)
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

function getstats(factor::AbstractFactor{T}; selector::AbstractBoolVariate = BoolVariate("", BitArray{1}())) where {T<:Unsigned}
    len = length(factor)
    levels = getlevels(factor)
    levelcount = length(levels)
    slices = slice(factor, 1, len, SLICELENGTH)
    noselector = length(selector) == 0
    if noselector
        init = zeros(Int64, levelcount + 1)
        freq = fold(init, slices) do frq, slice
            for levelindex in slice
                frq[levelindex + 1] += 1 
            end
            frq
        end
    else
        selslices = slice(selector, 1, len, SLICELENGTH)
        zipslices = zip(selslices, slices)
        stats0 = zeros(Int64, levelcount + 1)
        freq, selcount = fold((stats0, 0), zipslices) do acc, zipslice
            frq, k = acc
            selslice, slice = zipslice
            for i in 1:length(slice)
                if selslice[i]
                    k += 1
                    levelindex = slice[i]
                    frq[levelindex + 1] += 1 
                end
            end
            frq, k
        end
    end
    missingfreq = freq[1]
    missingpcnt = 100.0 * missingfreq / (noselector ? len : selcount)
    levelstats = [LevelStats(levels[i], freq[i + 1], 100.0 * freq[i + 1] / (noselector ? len : selcount)) for i in 1:levelcount]  
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
    zipslices = zip(factorslices, covslices)
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
    if slice1 !== nothing
        datahead = join([isnan(v) ? "." : string(v) for v in slice1], " ")
        dataend = len > HEADLENGTH ? "  ..." : ""
        println(io, "Covariate $(getname(covariate)) with $(len) obs: $(datahead)$dataend")
    else
        println(io, "Covariate $(getname(covariate)) with $(len) obs")
    end
end

function Base.show(io::IO, intvariate::AbstractIntVariate{T}) where {T<:Signed}
    slices = slice(intvariate, 1, HEADLENGTH, HEADLENGTH)
    slice1, _ = tryread(slices)
    len = length(intvariate)
    if slice1 !== nothing
        datahead = join([v == typemin(T) ? "." : string(v) for v in slice1], " ")
        dataend = len > HEADLENGTH ? "  ..." : ""
        println(io, "IntVariate $(getname(intvariate)) with $(len) obs: $(datahead)$dataend")
    else
        println(io, "IntVariate $(getname(intvariate)) with $(len) obs")
    end
end

function Base.show(io::IO, boolvar::AbstractBoolVariate) 
    slices = slice(boolvar, 1, HEADLENGTH, HEADLENGTH)
    slice1, _ = tryread(slices)
    len = length(boolvar)
    if slice1 !== nothing
        datahead = join([string(v) for v in slice1], " ")
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
    if slice1 !== nothing
        datahead = join([v == zero(Int64) ? MISSINGLEVEL : string(Dates.epochms2datetime(v)) for v in slice1], " ")
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
    if slice1 !== nothing
        datahead = join([index == 0 ? MISSINGLEVEL : levels[index] for index in slice1], " ")
        dataend = len > HEADLENGTH ? "  ..." : ""
        println(io, "Factor $(getname(factor)) with $(len) obs and $(levelcount) levels: $(datahead)$dataend")
    else
        println(io, "Factor $(getname(factor)) with $(len) obs and $(levelcount) levels")
    end
end

function Base.convert(::Type{Vector{T}}, factor::AbstractFactor{T}) where {T<:Unsigned}
    slices = slice(factor, 1, length(factor), SLICELENGTH)
    data = Vector{T}(undef, length(factor))
    fold(0, slices) do offset, slice
        n = length(slice)
        view(data, (1 + offset):(n + offset)) .= slice
        offset += n
    end
    data
end

function Base.convert(::Type{Vector{T}}, covariate::AbstractCovariate{T}) where {T<:AbstractFloat}
    slices = slice(covariate, 1, length(covariate), SLICELENGTH)
    data = Vector{T}(undef, length(covariate))
    fold(0, slices) do offset, slice
        n = length(slice)
        view(data, (1 + offset):(n + offset)) .= slice
        offset += n
    end
    data
end

function Base.convert(::Type{Vector{Int64}}, datetimevariate::AbstractDateTimeVariate) 
    slices = slice(datetimevariate, 1, length(datetimevariate), SLICELENGTH)
    data = Vector{Int64}(undef, length(datetimevariate))
    fold(0, slices) do offset, slice
        n = length(slice)
        view(data, (1 + offset):(n + offset)) .= slice
        offset += n
    end
    data
end

function Base.convert(::Type{BitArray{1}}, boolvariate::AbstractBoolVariate) 
    slices = slice(boolvariate, 1, length(boolvariate), SLICELENGTH)
    data = BitArray{1}(length(boolvariate))
    fold(0, slices) do offset, slice
        n = length(slice)
        view(data, (1 + offset):(n + offset)) .= slice
        offset += n
    end
    data
end

function Base.convert(::Type{Vector{Bool}}, boolvariate::AbstractBoolVariate) 
    slices = slice(boolvariate, 1, length(boolvariate), SLICELENGTH)
    data = Vector{Bool}(undef, length(boolvariate))
    fold(0, slices) do offset, slice
        n = length(slice)
        view(data, (1 + offset):(n + offset)) .= slice
        offset += n
    end
    data
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
    f = (x::T) -> isnan(x) ? "" : @sprintf("%F", x)
    slices = slice(covariate, fromobs, toobs, slicelength)
    mapslice(f, slices, slicelength, String)
end

function slicestring(intvariate::AbstractIntVariate{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Signed}
    slicelength = verifyslicelength(fromobs, toobs, slicelength)
    f = (x::T) -> x == typemin(T) ? "" : @sprintf("%D", x)
    slices = slice(intvariate, fromobs, toobs, slicelength)
    mapslice(f, slices, slicelength, String)
end

function tocsv(path::String, dataframe::AbstractDataFrame)
    path = abspath(path)
    iostream = open(path, "w")
    factors = dataframe.factors
    covariates = dataframe.covariates
    intvariates = dataframe.intvariates
    variates = [factors; covariates; intvariates]
    len = length(dataframe)
    strslices = zip(Tuple([slicestring(v, 1, len, SLICELENGTH) for v in variates]))
    ncol = length(variates)
    colnames = [getname(v) for v in variates]
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

function Base.eltype(x::AbstractFactor{T}) where {T<:Unsigned}
    T
end

function Base.eltype(x::AbstractCovariate{T}) where {T<:AbstractFloat}
    T
end

function Base.eltype(x::AbstractBoolVariate) 
    Bool
end

function Base.eltype(x::AbstractDateTimeVariate) 
    Int64
end

function Base.eltype(x::AbstractIntVariate{T}) where {T<:Signed}
    T
end

function Base.filter(selector::AbstractBoolVariate, dataframe::DataFrame)
    headerpath = dataframe.headerpath
    selectorname = getname(selector)
    outtempfolder = joinpath(normpath(joinpath(dirname(headerpath), "..")), randstring(10))
    outfolder = joinpath(normpath(joinpath(dirname(headerpath), "..")), selectorname)
    mkpath(outtempfolder)
    headerjson = open(headerpath) do f 
        readstring(f)
    end
    header = JSON.parse(headerjson) 
    datacols = header["datacolumns"]
    selector = convert(BitArray{1}, selector)
    for datacol in datacols
        datatype = datacol["datatype"]
        len = datacol["length"]
        name = datacol["name"]
        datpath = joinpath(dirname(headerpath), datacol["filename"])
        newfilename = "$(randstring(10)).dat"
        outdatpath = joinpath(outtempfolder, newfilename)

        T = 
            if datatype == "Float32"
                Float32
            elseif datatype == "Float64"
                    Float64
            elseif datatype == "Int32"
                Int32
            elseif datatype == "DateTime"
                Int64
            elseif datatype == "UInt8"
                UInt8
            elseif datatype == "UInt16"
                UInt16
            else 
                UInt32
            end
        data = Vector{T}(undef, len)
        open(datpath) do f
            read!(f, data)
        end
        seldata = data[selector]
        open(outdatpath, "a") do f
            @inbounds for i in 1:(length(seldata))
                write(f, seldata[i])
            end
        end
        datacol["length"] = length(seldata)
        datacol["filename"] = newfilename
    end
    
    newheader = DataHeader([DataColumnInfo(x["name"], x["length"], x["filename"], x["datatype"], [string(level) for level in x["levels"]]) for x in datacols])
    newheaderjson = JSON.json(newheader)
    newheaderpath = joinpath(outtempfolder, "header.txt")
    open(newheaderpath, "a") do f
        write(f, newheaderjson)
    end
    mv(outtempfolder, outfolder; remove_destination = true)   
end

function clearjumltmpdir()
    tmpjuml = joinpath(tempdir(), JUMLDIR)
    rm(tmpjuml; force = true, recursive = true)
end

