import Base.Iterators
import JSON

using Dates
using Random

abstract type ColumnImporter end

mutable struct CatImporter <: ColumnImporter
    colname::AbstractString
    colindex::Int64
    filepath::String
    length::Int64
    levelmap::Dict{SubString{String}, Int64}
    levelindexmap::Dict{Int64, SubString{String}}
    levelfreq::Dict{SubString{String}, Int64}
    isdropped::Bool
    isnumeric::Function
    isdatetime::Function
    isinteger::Function
    nas::Set{String}
    bitwidth::Int64
end

mutable struct NumImporter <: ColumnImporter
    colname::AbstractString
    colindex::Int64
    filepath::String
    length::Int64
    nancount::Int64
    zerocount::Int64
    nas::Set{String}
end

mutable struct IntImporter <: ColumnImporter
    colname::AbstractString
    colindex::Int64
    filepath::String
    length::Int64
    nas::Set{String}
end

mutable struct DateTimeImporter <: ColumnImporter
    colname::AbstractString
    colindex::Int64
    filepath::String
    length::Int64
    dtformat::DateFormat
    nas::Set{String}
end

function CatImporter(colname::AbstractString, colindex::Int64, filepath::String, len::Int64, isnumeric::Function, isdatetime::Function, isinteger::Function,
                     nas::Set{String}, isdropped)
    CatImporter(colname, colindex, filepath, len, Dict{SubString{String}, Int64}(MISSINGLEVEL => 0), Dict{Int64, SubString{String}}(0 => MISSINGLEVEL), Dict{SubString{String}, Int64}(), isdropped, isnumeric, isdatetime, isinteger, nas, 8)
end

mutable struct DataColumnInfo
    name::AbstractString
    length::Int64
    filename::String
    datatype::String
    levels::Vector{String}
end

function DataColumnInfo(catimporter::CatImporter)
    levelcount = length(catimporter.levelmap)
    datatype = levelcount <= typemax(UInt8) + 1 ? "UInt8" : (levelcount <= typemax(UInt16) + 1 ? "UInt16" : "UInt32")
    levels = Vector{String}(undef, levelcount - 1)
    for (k, v) in catimporter.levelmap
        if v > 0
            levels[v] = k
        end
    end
    DataColumnInfo(catimporter.colname, catimporter.length, basename(catimporter.filepath), datatype, levels)
end

function DataColumnInfo(numimporter::NumImporter)
    DataColumnInfo(numimporter.colname, numimporter.length, basename(numimporter.filepath), "Float32", Vector{String}())
end

function DataColumnInfo(intimporter::IntImporter)
    DataColumnInfo(intimporter.colname, intimporter.length, basename(intimporter.filepath), "Int64", Vector{String}())
end

function DataColumnInfo(dtimporter::DateTimeImporter)
    DataColumnInfo(dtimporter.colname, dtimporter.length, basename(dtimporter.filepath), "DateTime", Vector{String}())
end

struct DataHeader
    datacolumns::Vector{DataColumnInfo}
end

function widencatcolumn(::Type{T}, ::Type{S}, frompath::String, topath::String, length::Int64) where {T<:Unsigned} where {S<:Unsigned}
    buffer = Array{T}(undef, length)
    open(frompath) do fromfile
        open(topath, "a") do tofile
            read!(fromfile, buffer)
            write(tofile, convert(Vector{S}, buffer))
        end
    end
end

function tonumcolumn(::Type{T}, levelindexmap::Dict{Int64, SubString{String}}, frompath::String, topath::String, length::Int64) where {T<:Unsigned}
    data = Vector{T}(undef, length)
    open(frompath) do fromfile
        open(topath, "a") do tofile
            read!(fromfile, data)
            for i in 1:length
                level = levelindexmap[data[i]]
                v = tryparse(Float32, level)
                if v === nothing
                    write(tofile, NaN32)
                else
                    write(tofile, v)
                end              
            end
        end
    end
end

function tointcolumn(::Type{T}, levelindexmap::Dict{Int64, SubString{String}}, frompath::String, topath::String, length::Int64) where {T<:Unsigned}
    data = Vector{T}(undef, length)
    open(frompath) do fromfile
        open(topath, "a") do tofile
            read!(fromfile, data)
            for i in 1:length
                level = levelindexmap[data[i]]
                v = tryparse(Int64, level)
                if v === nothing
                    write(tofile, typemin(Int64))
                else
                    write(tofile, v)
                end              
            end
        end
    end
end

function todatetimecolumn(::Type{T}, dtformat::Dates.DateFormat, levelindexmap::Dict{Int64, SubString{String}}, frompath::String, topath::String, length::Int64) where {T<:Unsigned}
    data = Vector{T}(undef, length)
    open(frompath) do fromfile
        open(topath, "a") do tofile
            read!(fromfile, data)
            for i in 1:length
                level = levelindexmap[data[i]]
                ms = try
                         level == MISSINGLEVEL ? zero(Int64) : begin
                             dt = DateTime(level, dtformat)
                             ms = Dates.datetime2epochms(dt)
                         end
                     catch
                        zero(Int64)
                     end
                write(tofile, ms)
            end
        end
    end
end

function importlevels(colimporter::NumImporter, datalines::Vector{Vector{SubString{String}}})
    iostream = open(colimporter.filepath, "a")
    collength = colimporter.length
    nas = colimporter.nas
    colindex = colimporter.colindex
    for line in datalines
        level = colindex == 0 ? "" : strip(strip(line[colindex]), ['"'])
        level in nas ? write(iostream, NaN32) : begin
            v = tryparse(Float32, level)
            if v === nothing
                write(iostream, NaN32)
            else
                write(iostream, v)
            end
       end
        collength += 1
    end
    close(iostream)
    colimporter.length = collength
    colimporter
end

function importlevels(colimporter::IntImporter, datalines::Vector{Vector{SubString{String}}})
    iostream = open(colimporter.filepath, "a")
    collength = colimporter.length
    nas = colimporter.nas
    colindex = colimporter.colindex
    for line in datalines
        level = colindex == 0 ? "" : strip(strip(line[colindex]), ['"'])
        level in nas ? write(iostream, typemin(Int64)) : begin
            v = tryparse(Int64, level)
            if v === nothing
                write(iostream, typemin(Int64))
            else
                write(iostream, v)
            end
       end
        collength += 1
    end
    close(iostream)
    colimporter.length = collength
    colimporter
end

function importlevels(colimporter::DateTimeImporter, datalines::Vector{Vector{SubString{String}}})
    iostream = open(colimporter.filepath, "a")
    collength = colimporter.length
    dtformat = colimporter.dtformat
    nas = colimporter.nas
    colindex = colimporter.colindex
    for line in datalines
        level = colindex == 0 ? "" : strip(strip(line[colindex]), ['"'])
        ms = try
            level in nas ? zero(Int64) : begin
                dt = DateTime(level, dtformat)
                ms = Dates.datetime2epochms(dt)
            end
        catch
           zero(Int64)
        end
       write(iostream, ms)
       collength += 1
    end
    close(iostream)
    colimporter.length = collength
    colimporter
end

function importlevels(colimporter::CatImporter, datalines::Vector{Vector{SubString{String}}})
    if !colimporter.isdropped

        levelmap = colimporter.levelmap
        levelindexmap = colimporter.levelindexmap
        levelfreq = colimporter.levelfreq
        nas = colimporter.nas
        iostream = open(colimporter.filepath, "a")
        collength = colimporter.length
        colindex = colimporter.colindex

        for line in datalines
            bitwidth = colimporter.bitwidth
            level = colindex == 0 ? "" : strip(strip(line[colindex]), ['"'])
            if level in nas
                level = MISSINGLEVEL
            end
            levelcount = length(levelmap)
            levelindex = get(levelmap, level, levelcount)
            freq = get(levelfreq, level, 0)
            levelmap[level] = levelindex
            levelindexmap[levelindex] = level
            levelfreq[level] = freq + 1
            if bitwidth == 8 && length(levelmap) > typemax(UInt8) + 1
                newpath = joinpath(dirname(colimporter.filepath), "$(randstring(10)).dat")
                close(iostream)
                widencatcolumn(UInt8, UInt16, colimporter.filepath, newpath, collength)
                oldpath = colimporter.filepath
                colimporter.filepath = newpath
                colimporter.bitwidth = 16
                iostream = open(newpath, "a")
                rm(oldpath)          
            elseif bitwidth == 16 && length(levelmap) > typemax(UInt16) + 1   
                newpath = joinpath(dirname(colimporter.filepath), "$(randstring(10)).dat")
                close(iostream)
                widencatcolumn(UInt16, UInt32, colimporter.filepath, newpath, collength)
                oldpath = colimporter.filepath
                colimporter.filepath = newpath
                colimporter.bitwidth = 32
                iostream = open(newpath, "a")
                rm(oldpath)
            end
            if colimporter.bitwidth == 8
                write(iostream, convert(UInt8, levelindex))
            elseif colimporter.bitwidth == 16
                write(iostream, convert(UInt16, levelindex))
            elseif colimporter.bitwidth == 32
                write(iostream, convert(UInt32, levelindex))
            end
            levelcount = length(colimporter.levelmap)
            if levelcount > typemax(UInt32) + 1 
                colimporter.isdropped = true
                rm(colimporter.filepath)
            end
            collength += 1
        end
        colimporter.length = collength
        close(iostream)

        if !colimporter.isdropped && colimporter.isinteger(colimporter.colname, levelfreq)
                newpath = joinpath(dirname(colimporter.filepath), "$(randstring(10)).dat")
                if length(colimporter.levelmap) > typemax(UInt16) + 1
                    tointcolumn(UInt32, levelindexmap, colimporter.filepath, newpath, collength)
                elseif length(colimporter.levelmap) > typemax(UInt8) + 1
                    tointcolumn(UInt16, levelindexmap, colimporter.filepath, newpath, collength)
                else
                    tointcolumn(UInt8, levelindexmap, colimporter.filepath, newpath, collength)
                end
                rm(colimporter.filepath)
                colimporter = IntImporter(colimporter.colname, colimporter.colindex, newpath, collength, nas)
       
        elseif !colimporter.isdropped && colimporter.isnumeric(colimporter.colname, levelfreq)
            newpath = joinpath(dirname(colimporter.filepath), "$(randstring(10)).dat")
            if length(colimporter.levelmap) > typemax(UInt16) + 1
                tonumcolumn(UInt32, levelindexmap, colimporter.filepath, newpath, collength)
            elseif length(colimporter.levelmap) > typemax(UInt8) + 1
                tonumcolumn(UInt16, levelindexmap, colimporter.filepath, newpath, collength)
            else
                tonumcolumn(UInt8, levelindexmap, colimporter.filepath, newpath, collength)
            end
            rm(colimporter.filepath)
            colimporter = NumImporter(colimporter.colname, colimporter.colindex, newpath, collength, 0, 0, nas)

        else
            isdt, dtformatstr = colimporter.isdatetime(colimporter.colname, levelfreq)
            dtformat = Dates.DateFormat(dtformatstr)
            if !colimporter.isdropped && isdt
                newpath = joinpath(dirname(colimporter.filepath), "$(randstring(10)).dat")
                if length(colimporter.levelmap) > typemax(UInt8) + 1
                    todatetimecolumn(UInt16, dtformat, levelindexmap, colimporter.filepath, newpath, collength)
                else
                    todatetimecolumn(UInt8, dtformat, levelindexmap, colimporter.filepath, newpath, collength)
                end
                rm(colimporter.filepath)
                colimporter = DateTimeImporter(colimporter.colname, colimporter.colindex, newpath, collength, dtformat, nas)
            end
        end
    end
    colimporter
end

function importdata(colimporters::Vector{ColumnImporter}, datalines::Vector{Vector{SubString{String}}})
    colcount = length(colimporters)
    for i = 1:colcount
        colimporters[i] = importlevels(colimporters[i], datalines)
    end
    colimporters
end

function isanylevelnumeric(colname::AbstractString, levelfreq::Dict{SubString{String}, Int64})
    any([tryparse(Float32, strip(k)) !== nothing for k in keys(levelfreq)])
end

function isnotdatetime(colname::AbstractString, levelfreq::Dict{SubString{String}, Int64})
    false, ""
end

function isnotinteger(colname::AbstractString, levelfreq::Dict{SubString{String}, Int64})
    false
end

function importcsv(path::String; colnames::Vector{String} = Vector{String}(), path2::String = "", sep = ",", outname::String = "", maxobs::Integer = -1, chunksize::Integer = SLICELENGTH, nas::Vector{String} = Vector{String}(),
                   isnumeric::Function = isanylevelnumeric, isdatetime::Function = isnotdatetime, isinteger::Function = isnotinteger,
                   drop::Vector{String} = Vector{String}())
    nas = Set{String}(nas)
    push!(nas, "")
    path = abspath(path)
    outfolder = outname == "" ? (path2 == "" ? splitext(path)[1] : splitext(path)[1] * splitext(basename(path2))[1]) : joinpath(dirname(path), outname)
    outtempfolder = joinpath(dirname(path), randstring(10))
    mkpath(outtempfolder)
    iostream = open(path)
    lineseq = maxobs > -1 ? Iterators.take(Seq(String, iostream, nextline), maxobs + 1) : Seq(String, iostream, nextline) 
    datalines = map((line -> split(line, sep)), lineseq, Vector{SubString{String}})
    if length(colnames) == 0
        colnames, datalines = datalines |> tryread
        colnames = map((c -> strip(strip(c), ['"'])), colnames)
    end
    
    if colnames !== nothing
        colimporters::Vector{ColumnImporter} = map((x -> CatImporter(x[2], x[1], joinpath(outtempfolder, "$(randstring(10)).dat"), 0, isnumeric, isdatetime, isinteger, nas, x[2] in drop)), enumerate(colnames))
        colimporters = fold(importdata, colimporters, chunkbysize(datalines, chunksize))
    end
    if path2 != ""
        iostream2 = open(path2)
        line2seq = Seq(String, iostream2, nextline)
        lines2 = map((line -> split(line, ",")), line2seq, Vector{SubString{String}})
        colnames2, datalines2 = lines2 |> tryread
        if colnames2 !== nothing
            currlen = colimporters[1].length
            colnames2 = map((c -> strip(strip(c), ['"'])), colnames2)
            colimporters2::Vector{ColumnImporter} = map(enumerate(colnames2)) do x
                colindex, colname = x
                i = findfirst((c -> c.colname == colname), colimporters)
                if i > 0
                    colimp = colimporters[i]
                    colimp.colindex = colindex
                    colimp
                else
                    if isnumeric(colname, Dict{SubString{String}, Int64}())
                        newpath = joinpath(outtempfolder, "$(randstring(10)).dat")
                        open(newpath, "a") do tofile
                            for i in 1:currlen
                                write(tofile, NaN32)
                            end
                        end
                        NumImporter(colname, colindex, newpath, currlen, 0, 0, nas)
                    elseif isinteger(colname, Dict{SubString{String}, Int64}())
                            newpath = joinpath(outtempfolder, "$(randstring(10)).dat")
                            open(newpath, "a") do tofile
                                for i in 1:currlen
                                    write(tofile, typemin(Int32))
                                end
                            end
                            IntImporter(colname, colindex, newpath, currlen, nas)
                    else
                        newpath = joinpath(outtempfolder, "$(randstring(10)).dat")
                        open(newpath, "a") do tofile
                            for i in 1:currlen
                                write(tofile, zero(UInt8))
                            end
                        end
                        CatImporter(colname, colindex, newpath, currlen, isnumeric, isdatetime, nas, colname in drop)
                    end
                end
            end
            for colimp in colimporters
                if findfirst((c -> c.colname == colimp.colname), colimporters2) == 0
                    colimp.colindex = 0
                    push!(colimporters2, colimp)
                end
            end
            colimporters2 = fold(importdata, colimporters2, chunkbysize(datalines2, chunksize))
            colimporters = colimporters2
        end
    end

    colimporters = filter(colimporters) do colimp
        isa(colimp, NumImporter) || isa(colimp, IntImporter) || isa(colimp, DateTimeImporter) || !colimp.isdropped
    end
    header = DataHeader([DataColumnInfo(colimp) for colimp in colimporters])
    headerjson = JSON.json(header)
    headerpath = joinpath(outtempfolder, "header.txt")
    open(headerpath, "a") do f
        write(f, headerjson)
    end
    mv(outtempfolder, outfolder; force = true)
end
