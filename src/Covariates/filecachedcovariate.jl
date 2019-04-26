mutable struct FileCachedCovariate{T<:AbstractFloat, S<:AbstractCovariate{T}} <: AbstractCovariate{T}
    cachepath::String
    basecovariate::S
    lockobj::Threads.TatasLock

    FileCachedCovariate{T, S}(cachepath, basecovariate, lockobj) where {S<:AbstractCovariate{T}} where {T<:AbstractFloat} = begin
        res = new(cachepath, basecovariate, lockobj)
        finalizer(res, x -> begin
            try
                if isfile(x.cachepath) 
                    rm(x.cachepath) 
                end
            finally
            end
            end)
        res
    end
end

Base.length(var::FileCachedCovariate) = length(var.basecovariate)

getname(var::FileCachedCovariate) = getname(var.basecovariate)

function FileCachedCovariate(covariate::S) where {S<:AbstractCovariate{T}} where {T<:AbstractFloat}
    FileCachedCovariate{T, S}("", covariate, Threads.TatasLock()) 
end

function filecache(covariate::S) where {S<:AbstractCovariate{T}} where {T<:AbstractFloat}
    FileCachedCovariate{T, S}("", covariate, Threads.TatasLock()) 
end

function slice(covariate::FileCachedCovariate{T, S}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat} where {S<:Union{FileCachedCovariate, CachedCovariate, Covariate, FileCovariate}}
    basecovariate = covariate.basecovariate
    slicelength = verifyslicelength(fromobs, toobs, slicelength)  
    slice(basecovariate, fromobs, toobs, slicelength)
end

function slice(covariate::FileCachedCovariate{T, S}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {S<:AbstractCovariate{T}} where {T<:AbstractFloat}
    basecovariate = covariate.basecovariate
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    lockobj = covariate.lockobj
    lock(lockobj)
    try
        if !isfile(covariate.cachepath)
            v = convert(Vector{T}, basecovariate)
            tmpjuml = joinpath(tempdir(), JUMLDIR)
            mkpath(tmpjuml)
            outdatpath = joinpath(tmpjuml, "$(randstring(10)).dat")
            open(outdatpath, "w") do f
                write(f, v)
            end
            covariate.cachepath = outdatpath
        end
    finally
        unlock(lockobj)
    end
    sizeT = sizeof(T)
    iostream = open(covariate.cachepath, "r")
    seek(iostream, sizeT * (fromobs - 1))
    buffer = Vector{T}(undef, slicelength)
    map(Seq(Vector{T}, (buffer, iostream, fromobs, toobs, slicelength), nextdatachunk), SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}) do slice
        view(slice, 1:length(slice))
    end
end

function Base.map(covariate::FileCachedCovariate, dataframe::AbstractDataFrame)
    FileCachedCovariate(map(covariate.basecovariate, dataframe))
end