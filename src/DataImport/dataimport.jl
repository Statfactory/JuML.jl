import Base.Iterators
import JSON

abstract type ColumnImporter end

mutable struct CatImporter <: ColumnImporter
    colname::AbstractString
    filepath::String
    length::Int64
    levelmap::Dict{String, Int64}
    levelindexmap::Dict{Int64, String}
    levelfreq::Dict{String, Int64}
    isdropped::Bool
    isnumeric::Function
    nas::Set{String}
end

mutable struct NumImporter <: ColumnImporter
    colname::AbstractString
    filepath::String
    length::Int64
    nancount::Int64
    zerocount::Int64
end

function CatImporter(colname::AbstractString, outfolder::String, isnumeric::Function, nas::Set{String}, isdropped)
    filepath = joinpath(outfolder, "$(randstring(10)).dat")
    CatImporter(colname, filepath, 0, Dict{String, Int64}(MISSINGLEVEL => 0), Dict{Int64, String}(0 => MISSINGLEVEL), Dict{String, Int64}(), isdropped, isnumeric, nas)
end

struct DataColumnInfo
    name::AbstractString
    length::Int64
    filename::String
    datatype::String
    levels::Vector{String}
end

function DataColumnInfo(catimporter::CatImporter)
    levelcount = length(catimporter.levelmap)
    datatype = levelcount <= typemax(UInt8) + 1 ? "UInt8" : (levelcount <= typemax(UInt16) + 1 ? "UInt16" : UInt32)
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

function importlevels(colimporter::NumImporter, datalines::Vector{Vector{SubString{String}}}, colindex::Integer)
    iostream = open(colimporter.filepath, "a")
    collength = colimporter.length
    for line in datalines
        level = line[colindex]
        v = tryparse(Float32, level)
        if isnull(v)
            write(iostream, NaN32)
        else
            write(iostream, get(v))
        end
        collength += 1
    end
    close(iostream)
    colimporter.length = collength
    colimporter
end


function importlevels(colimporter::CatImporter, datalines::Vector{Vector{SubString{String}}}, colindex::Integer)
    if !colimporter.isdropped

        levelmap = colimporter.levelmap
        levelindexmap = colimporter.levelindexmap
        levelfreq = colimporter.levelfreq
        nas = colimporter.nas
        iostream = open(colimporter.filepath, "a")
        collength = colimporter.length

        for line in datalines
            level = strip(strip(line[colindex]), ['"'])
            if level in nas
                level = MISSINGLEVEL
            end
            levelcount = length(levelmap)
            levelindex = get(levelmap, level, levelcount)
            freq = get(levelfreq, level, 0)
            levelmap[level] = levelindex
            levelindexmap[levelindex] = level
            levelfreq[level] = freq + 1
            if freq == 0 && levelcount == typemax(UInt8) + 1
                newpath = joinpath(dirname(colimporter.filepath), "$(randstring(10)).dat")
                close(iostream)
                widencatcolumn(colimporter.filepath, newpath, collength)
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
            collength += 1
        end
        colimporter.length = collength
        close(iostream)
        if colimporter.isdropped
            rm(colimporter.filepath)
        end
        if !colimporter.isdropped && colimporter.isnumeric(colimporter.colname, levelfreq)
            newpath = joinpath(dirname(colimporter.filepath), "$(randstring(10)).dat")
            if length(colimporter.levelmap) > typemax(UInt8) + 1
                uint16tonumcolumn(levelindexmap, colimporter.filepath, newpath, collength)
            else
                uint8tonumcolumn(levelindexmap, colimporter.filepath, newpath, collength)
            end
            rm(colimporter.filepath)
            colimporter = NumImporter(colimporter.colname, newpath, collength, 0, 0)
        end
    end
    colimporter
end

function importdata(colimporters::Vector{ColumnImporter}, datalines::Vector{Vector{SubString{String}}})
    colcount = length(colimporters)
    Threads.@threads for i = 1:colcount
        colimporters[i] = importlevels(colimporters[i], datalines, i)
    end
    colimporters
end

function isanylevelnumeric(colname::AbstractString, levelfreq::Dict{String, Int64})
    any([!isnull(tryparse(Float32, strip(k))) for k in keys(levelfreq)])
end

function importcsv(path::String; path2::String = "", outname::String = "", maxobs::Integer = -1, chunksize::Integer = SLICELENGTH, nas::Vector{String} = Vector{String}(),
                   isnumeric::Function = isanylevelnumeric, drop::Vector{String} = Vector{String}())
    nas = Set{String}(nas)
    push!(nas, "")
    path = abspath(path)
    outfolder = outname == "" ? (path2 == "" ? splitext(path)[1] : splitext(path)[1] * splitext(basename(path2))[1]) : joinpath(dirname(path), outname)
    outtempfolder = joinpath(dirname(path), randstring(10))
    mkpath(outtempfolder)
    iostream = open(path)
    lineseq = maxobs > -1 ? Iterators.take(Seq(String, iostream, nextline), maxobs + 1) : begin 
        if path2 == ""
            Seq(String, iostream, nextline)
        else
            s1 = Seq(String, iostream, nextline)
            iostream2 = open(path2)
            s2 = Seq(String, iostream2, nextline)
            _, s2 = tryread(s2)
            concat(s1, s2)
        end
    end
    lines = map((line -> split(line, ",")), lineseq, Vector{SubString{String}})
    colnames, datalines = lines |> tryread
    if !isnull(colnames)
        colnames = map((c -> strip(strip(c), ['"'])), get(colnames))
        colimporters::Vector{ColumnImporter} = map((colname -> CatImporter(colname, outtempfolder, isnumeric, nas, colname in drop)), colnames)
        colimporters = fold(importdata, colimporters, chunkbysize(datalines, chunksize))
    end
    colimporters = filter(colimporters) do colimp
        isa(colimp, NumImporter) || !colimp.isdropped
    end
    header = DataHeader([DataColumnInfo(colimp) for colimp in colimporters])
    headerjson = JSON.json(header)
    headerpath = joinpath(outtempfolder, "header.txt")
    open(headerpath, "a") do f
        write(f, headerjson)
    end
    mv(outtempfolder, outfolder; remove_destination = true)
end
