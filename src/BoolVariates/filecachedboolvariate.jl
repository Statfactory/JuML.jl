mutable struct FileCachedBoolVariate{S<:AbstractBoolVariate} <: AbstractBoolVariate
    cachepath::String
    basevariate::S
    lockobj::Threads.TatasLock

    FileCachedBoolVariate{S}(cachepath, basevariate, lockobj) where {S<:AbstractBoolVariate} = (res = new(cachepath, basevariate, lockobj); finalizer(res, x -> rm(x.cachepath; force = true)); res)
end

Base.length(var::FileCachedBoolVariate) = length(var.basevariate)

getname(var::FileCachedBoolVariate) = getname(var.basevariate)

function FileCachedBoolVariate(basevariate::S) where {S<:AbstractBoolVariate} 
    FileCachedBoolVariate{S}("", basevariate, Threads.TatasLock()) 
end

function filecache(basevariate::S) where {S<:AbstractBoolVariate} 
    FileCachedBoolVariate{S}("", basevariate, Threads.TatasLock()) 
end

function slice(boolvar::FileCachedBoolVariate{S}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {S<:Union{FileCachedBoolVariate, CachedBoolVariate, BoolVariate}}
    basevariate = boolvar.basevariate
    slicelength = verifyslicelength(fromobs, toobs, slicelength)  
    slice(basevariate, fromobs, toobs, slicelength)
end

function slice(boolvar::FileCachedBoolVariate{S}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {S<:AbstractBoolVariate}
    basevariate = boolvar.basevariate
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    lockobj = boolvar.lockobj
    lock(lockobj)
    try
        if !isfile(boolvar.cachepath)
            v = convert(Vector{Bool}, basevariate)
            tmpjuml = joinpath(tempdir(), JUMLDIR)
            mkpath(tmpjuml)
            outdatpath = joinpath(tmpjuml, "$(randstring(10)).dat")
            open(outdatpath, "w") do f
                write(f, v)
            end
            boolvar.cachepath = outdatpath
        end
    finally
        unlock(lockobj)
    end
    sizeT = sizeof(Bool)
    iostream = open(boolvar.cachepath, "r")
    seek(iostream, sizeT * (fromobs - 1))
    buffer = Vector{Bool}(undef, slicelength)
    map(Seq(Vector{Bool}, (buffer, iostream, fromobs, toobs, slicelength), nextdatachunk), SubArray{Bool,1,Array{Bool,1},Tuple{UnitRange{Int64}},true}) do slice
        view(slice, 1:length(slice))
    end
end

function Base.map(boolvariate::FileCachedBoolVariate, dataframe::AbstractDataFrame)
    FileCachedBoolVariate(map(boolvariate.basevariate, dataframe))
end