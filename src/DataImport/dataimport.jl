import Base.Iterators
import JSON

abstract type ColumnImporter end

mutable struct CatImporter <: ColumnImporter
    colname::String
    filepath::String
    length::Int64
    levelmap::Dict{String, Int64}
    levelindexmap::Dict{Int64, String}
    levelfreq::Dict{String, Int64}
    isdropped::Bool
    isnumeric::Function
end

mutable struct NumImporter <: ColumnImporter
    colname::String
    filepath::String
    length::Int64
    nancount::Int64
    zerocount::Int64
end

function CatImporter(colname::String, outfolder::String, isnumeric::Function)
    filepath = joinpath(outfolder, "$(randstring(10)).dat")
    CatImporter(colname, filepath, 0, Dict{String, Int64}(MISSINGLEVEL => 0), Dict{Int64, String}(0 => MISSINGLEVEL), Dict{String, Int64}(), false, isnumeric)
end

struct DataColumnInfo
    name::String
    length::Int64
    filename::String
    datatype::String
    levels::Vector{String}
end

function DataColumnInfo(catimporter::CatImporter)
    levelcount = length(catimporter.levelmap)
    datatype = levelcount <= typemax(UInt8) + 1 ? "UInt8" : "UInt16"
    levels = Vector{String}(levelcount - 1)
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

struct DataHeader
    datacolumns::Vector{DataColumnInfo}
end

function widencatcolumn(frompath::String, topath::String, length::Int64)
    buffer = Array{UInt8}(1)
    open(frompath) do fromfile
        open(topath, "a") do tofile
            for i in 1:length
                readbytes!(fromfile, buffer)
                v::UInt16 = UInt16(buffer[1])
                write(tofile, v)
            end
        end
    end
end

function uint8tonumcolumn(levelindexmap::Dict{Int64, String}, frompath::String, topath::String, length::Int64)
    buffer = Array{UInt8}(1)
    open(frompath) do fromfile
        open(topath, "a") do tofile
            for i in 1:length
                readbytes!(fromfile, buffer)
                level::String = levelindexmap[buffer[1]]
                v = tryparse(Float32, level)
                if isnull(v)
                    write(tofile, NaN32)
                else
                    write(tofile, get(v))
                end
            end
        end
    end
end

function uint16tonumcolumn(levelindexmap::Dict{Int64, String}, frompath::String, topath::String, length::Int64)
    buffer = Array{UInt8}(2)
    open(frompath) do fromfile
        open(topath, "a") do tofile
            for i in 1:length
                readbytes!(fromfile, buffer)
                uint16Arr = reinterpret(UInt16, buffer)
                level::String = levelindexmap[uint16Arr[1]]
                v = tryparse(Float32, level)
                if isnull(v)
                    write(tofile, NaN32)
                else
                    write(tofile, get(v))
                end
            end
        end
    end
end

function importlevels(colimporter::NumImporter, levels::Vector{String})
    iostream = open(colimporter.filepath, "a")
    for level in levels
        v = tryparse(Float32, level)
        if isnull(v)
            write(iostream, NaN32)
        else
            write(iostream, get(v))
        end
        colimporter.length += 1
    end
    close(iostream)
    colimporter
end


function importlevels(colimporter::CatImporter, levels::Vector{String})
    if !colimporter.isdropped

        levelmap = colimporter.levelmap
        levelindexmap = colimporter.levelindexmap
        levelfreq = colimporter.levelfreq
        iostream = open(colimporter.filepath, "a")

        for level in levels
            levelcount = length(levelmap)
            levelindex = get(levelmap, level, levelcount)
            freq = get(levelfreq, level, 0)
            levelmap[level] = levelindex
            levelindexmap[levelindex] = level
            levelfreq[level] = freq + 1
            if freq == 0 && levelcount == typemax(UInt8) + 1
                newpath = joinpath(dirname(colimporter.filepath), "$(randstring(10)).dat")
                close(iostream)
                widencatcolumn(colimporter.filepath, newpath, colimporter.length)
                oldpath = colimporter.filepath
                colimporter.filepath = newpath
                iostream = open(newpath, "a")
                rm(oldpath)
            end
            levelcount = length(colimporter.levelmap)
            if levelcount > typemax(UInt16) + 1 
                    colimporter.isdropped = true
                    println("dropped: $(colimporter.colname)")
                    break
            elseif levelcount > typemax(UInt8) + 1
                write(iostream, convert(UInt16, levelindex))
            else
                write(iostream, convert(UInt8, levelindex))
            end
            colimporter.length += 1
        end
        close(iostream)
        if colimporter.isdropped
            rm(colimporter.filepath)
        end
        if !colimporter.isdropped && colimporter.isnumeric(colimporter.colname, levelfreq)
            newpath = joinpath(dirname(colimporter.filepath), "$(randstring(10)).dat")
            if length(colimporter.levelmap) > typemax(UInt8) + 1
                uint16tonumcolumn(levelindexmap, colimporter.filepath, newpath, colimporter.length)
            else
                uint8tonumcolumn(levelindexmap, colimporter.filepath, newpath, colimporter.length)
            end
            colimporter = NumImporter(colimporter.colname, newpath, colimporter.length, 0, 0)
        end
    end
    colimporter
end

function importdata(colimporters::Vector{ColumnImporter}, datalines::Vector{Vector{String}})
    colcount = length(colimporters)
    coldata = begin
        foldl([Vector{String}() for i = 1:colcount], datalines) do acc, line
        for i = 1:colcount
            level = get(line, i, MISSINGLEVEL)
            if level == ""
                level = MISSINGLEVEL
            end
            push!(acc[i], level)
        end
        acc
        end
    end

    for i = 1:colcount
        levels = coldata[i]
        colimporters[i] = importlevels(colimporters[i], levels)
    end
    colimporters
end

function importcsv(path::String, maxobs::Integer, chunksize::Integer, isnumeric::Function)
    path = abspath(path)
    outfolder = splitext(path)[1]
    mkpath(outfolder)
    iostream = open(path)
    lines::Seq{Vector{String}} = map((line -> convert(Vector{String}, split(line, ","))), Iterators.take(Seq(String, iostream, nextline), maxobs + 1), Vector{String})
    colnames, datalines = lines |> tryread
    if !isnull(colnames)
        colnames = get(colnames)
        colimporters::Vector{ColumnImporter} = map((colname -> CatImporter(colname, outfolder, isnumeric)), colnames)
        colimporters = fold(importdata, colimporters, chunkbysize(datalines, chunksize))
    end
    header = DataHeader([DataColumnInfo(colimp) for colimp in colimporters])
    headerjson = JSON.json(header)
    headerpath = joinpath(outfolder, "header.txt")
    open(headerpath, "a") do f
        write(f, headerjson)
    end
end

function importcsv(path::String, maxobs::Integer, chunksize::Integer)
    isnumeric = (colname::String, levelfreq::Dict{String, Int64}) -> 
                 begin
                     res = false
                     for k in keys(levelfreq)
                         if !isnull(tryparse(Float32, k))
                            res = true
                            break
                         end
                     end
                    res
                 end
    importcsv(path, maxobs, chunksize, isnumeric)
end