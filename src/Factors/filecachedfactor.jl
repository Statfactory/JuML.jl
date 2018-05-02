mutable struct FileCachedFactor{T<:Unsigned} <: AbstractFactor{T}
    cachepath::String
    basefactor::AbstractFactor{T}
    lockobj::Threads.TatasLock

    FileCachedFactor{T}(cachepath, basefactor, lockobj) where {T<:Unsigned} = (res = new(cachepath, basefactor, lockobj); finalizer(res, x -> rm(x.cachepath; force = true)); res)
end

Base.length(var::FileCachedFactor) = length(var.basefactor)

getname(var::FileCachedFactor) = getname(var.basefactor)

getlevels(var::FileCachedFactor) = getlevels(var.basefactor)

function FileCachedFactor(factor::AbstractFactor{T}) where {T<:Unsigned}
    FileCachedFactor{T}("", factor, Threads.TatasLock()) 
end

function filecache(basefactor::AbstractFactor{T}) where {T<:Unsigned}
    FileCachedFactor{T}("", basefactor, Threads.TatasLock()) 
end

function slice(factor::FileCachedFactor{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned}
    basefactor = factor.basefactor
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    if isa(basefactor, FileCachedFactor) || isa(basefactor, Factor) || isa(basefactor, CachedFactor)
        slice(basefactor, fromobs, toobs, slicelength)
    else
        lockobj = factor.lockobj
        lock(lockobj)
        try
            if !isfile(factor.cachepath)
                slices = slice(basefactor, 1, length(basefactor), SLICELENGTH)
                tmpjuml = joinpath(tempdir(), JUMLDIR)
                mkpath(tmpjuml)
                outdatpath = joinpath(tmpjuml, "$(randstring(10)).dat")
                iter(slices) do slice
                    open(outdatpath, "a") do f
                        write(f, slice)
                    end
                end
                factor.cachepath = outdatpath
            end
        finally
            unlock(lockobj)
        end
        sizeT = sizeof(T)
        iostream = open(factor.cachepath)
        seek(iostream, sizeT * (fromobs - 1))
        buffer = Vector{T}(slicelength)
        map(Seq(Vector{T}, (buffer, iostream, fromobs, toobs, slicelength), nextdatachunk), SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}) do slice
            view(slice, 1:length(slice))
        end
    end
end

function Base.map(factor::FileCachedFactor{T}, dataframe::AbstractDataFrame; permute::Bool = false) where {T<:Unsigned}
    FileCachedFactor(map(factor.basefactor, dataframe; permute = permute))
end

function isordinal(factor::FileCachedFactor{T}) where {T<:Unsigned}
    isordinal(factor.basefactor)
end