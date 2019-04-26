mutable struct FileCachedFactor{T<:Unsigned, S<:AbstractFactor{T}} <: AbstractFactor{T}
    cachepath::String
    basefactor::S
    lockobj::Threads.TatasLock

    FileCachedFactor{T, S}(cachepath, basefactor, lockobj) where {S<:AbstractFactor{T}} where {T<:Unsigned} = (res = new(cachepath, basefactor, lockobj); finalizer(res, x -> rm(x.cachepath; force = true)); res)
end

Base.length(var::FileCachedFactor) = length(var.basefactor)

getname(var::FileCachedFactor) = getname(var.basefactor)

getlevels(var::FileCachedFactor) = getlevels(var.basefactor)

function FileCachedFactor(factor::S) where {S<:AbstractFactor{T}} where {T<:Unsigned}
    FileCachedFactor{T, S}("", factor, Threads.TatasLock()) 
end

function filecache(basefactor::S) where {S<:AbstractFactor{T}} where {T<:Unsigned}
    FileCachedFactor{T, S}("", basefactor, Threads.TatasLock()) 
end

function slice(factor::FileCachedFactor{T, S}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned} where {S<:Union{FileCachedFactor, CachedFactor, Factor, FileFactor}}
    basefactor = factor.basefactor
    slicelength = verifyslicelength(fromobs, toobs, slicelength)  
    slice(basefactor, fromobs, toobs, slicelength)
end

function slice(factor::FileCachedFactor{T, S}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {S<:AbstractFactor{T}} where {T<:Unsigned}
    basefactor = factor.basefactor
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    lockobj = factor.lockobj
    lock(lockobj)
    try
        if !isfile(factor.cachepath)
            v = convert(Vector{T}, basefactor)
            tmpjuml = joinpath(tempdir(), JUMLDIR)
            mkpath(tmpjuml)
            outdatpath = joinpath(tmpjuml, "$(randstring(10)).dat")
            open(outdatpath, "w") do f
                write(f, v)
            end
            factor.cachepath = outdatpath
        end
    finally
        unlock(lockobj)
    end
    sizeT = sizeof(T)
    iostream = open(factor.cachepath, "r")
    seek(iostream, sizeT * (fromobs - 1))
    buffer = Vector{T}(undef, slicelength)
    map(Seq(Vector{T}, (buffer, iostream, fromobs, toobs, slicelength), nextdatachunk), SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}) do slice
        view(slice, 1:length(slice))
    end
end

function Base.map(factor::FileCachedFactor{T}, dataframe::AbstractDataFrame; permute::Bool = false) where {T<:Unsigned}
    FileCachedFactor(map(factor.basefactor, dataframe; permute = permute))
end

function isordinal(factor::FileCachedFactor{T}) where {T<:Unsigned}
    isordinal(factor.basefactor)
end