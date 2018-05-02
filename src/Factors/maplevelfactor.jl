struct MapLevelFactor{S<:Unsigned, T<:Unsigned} <: AbstractFactor{T}
    name::String
    levels::AbstractVector{<:AbstractString}
    basefactor::AbstractFactor{S}
    transform::Function
    newindex::Vector{T}
end

Base.length(var::MapLevelFactor) = length(var.basefactor)

function MapLevelFactor(name::String, basefactor::AbstractFactor{S}, transform::Function) where {S<:Unsigned}
    baselevels = getlevels(basefactor)
    levelmap = Dict{String, S}()
    newlevels = Vector{String}()
    newindex = Vector{S}(length(baselevels) + 1)
    for (index, level) in enumerate(baselevels)
        newlevel = transform(level)
        if newlevel == MISSINGLEVEL
            newindex[index + 1] = zero(S)
        else
            levelcount = length(levelmap)
            levelindex = get(levelmap, newlevel, levelcount + 1)
            if levelindex > levelcount
                levelmap[newlevel] = levelindex
                newindex[index + 1] = levelindex
                push!(newlevels, newlevel)
            else
                newindex[index + 1] = levelindex
            end
        end
    end
    newmissing = transform(MISSINGLEVEL)
    if newmissing == MISSINGLEVEL
        newindex[1] = 0
    else
        levelcount = length(levelmap)
        levelindex = get(levelmap, newmissing, levelcount + 1)
        if levelindex > levelcount
            newindex[1] = levelindex
            push!(newlevels, newmissing)
        end
    end
    MapLevelFactor{S, S}(name, newlevels, basefactor, transform, newindex)
end

function slice(factor::MapLevelFactor{S, T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned} where {S<:Unsigned}
    newindex = factor.newindex
    f = (i::S -> newindex[i + 1])
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = slice(factor.basefactor, fromobs, toobs, slicelength)
    mapslice(f, slices, slicelength, T)
end

function Base.map(factor::MapLevelFactor{S, T}, dataframe::AbstractDataFrame; permute::Bool = false) where {S<:Unsigned} where {T<:Unsigned}
    MapLevelFactor(factor.name, map(factor.basefactor, dataframe; permute = permute), factor.transform)
end