mutable struct GroupStatsCovariate{N, U, S, T<:AbstractFloat} <: AbstractCovariate{T}
    name::String
    length::Int64
    groupstats::GroupStats{N, U, S}
    transform::Function
end

function GroupStatsCovariate(name::String, groupstats::GroupStats{N, U, S}, transform::Function) where {N} where {U} where {S}
    GroupStatsCovariate{N, U, S, Float32}(name, length(groupstats.keyvars[1]), groupstats, transform)
end

function GroupStatsCovariate(name::String, groupstats::GroupStats{N, U, S}) where {N} where {U} where {S}
    GroupStatsCovariate{N, U, S, Float32}(name, length(groupstats.keyvars[1]), groupstats, identity)
end

function GroupStatsCovariate(::Type{T}, name::String, groupstats::GroupStats{N, U, S}, transform::Function) where {T<:AbstractFloat} where {N} where {U} where {S}
    GroupStatsCovariate{N, U, S, T}(name, length(groupstats.keyvars[1]), groupstats, transform)
end

function GroupStatsCovariate(::Type{T}, name::String, groupstats::GroupStats{N, U, S}) where {T<:AbstractFloat} where {N} where {U} where {S}
    GroupStatsCovariate{N, U, S, T}(name, length(groupstats.keyvars[1]), groupstats, identity)
end

function slice(covariate::GroupStatsCovariate{N, U, S, T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat} where {N} where {U} where {S}
    keyvars = covariate.groupstats.keyvars
    eltypes = map((x -> eltype(x)), keyvars)
    dict = covariate.groupstats.stats
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    zipslices = zip(map((v -> slice(v, fromobs, toobs, slicelength)), keyvars))
    f = covariate.transform
    buffer = Vector{T}(undef, slicelength)
    t = zero(T)
    u = zero(U)
    s = zero(S)
    map(zipslices, SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}) do zipslice
        n = length(zipslice[1])
        if N == 1
            slice = zipslice[1]
            for i in 1:n
                buffer[i] = oftype(t, f(get(dict, (oftype(u, slice[i]), ), s)))
            end
            view(buffer, 1:n)
        elseif N == 2
            slice1, slice2 = zipslice
            for i in 1:n
                buffer[i] = oftype(t, f(get(dict, (oftype(u, slice1[i]), oftype(u, slice2[i])), s)))
            end
            view(buffer, 1:n)
        elseif N == 3
            slice1, slice2, slice3 = zipslice
            for i in 1:n
                buffer[i] = oftype(t, f(get(dict, (oftype(u, slice1[i]), oftype(u, slice2[i]), oftype(u, slice3[i])), s)))
            end
            view(buffer, 1:n)
        elseif N == 4
            slice1, slice2, slice3, slice4 = zipslice
            for i in 1:n
                buffer[i] = oftype(t, f(get(dict, (oftype(u, slice1[i]), oftype(u, slice2[i]), oftype(u, slice3[i]), oftype(u, slice4[i])), s)))
            end
            view(buffer, 1:n)
        else
            for i in 1:n
                buffer[i] = oftype(t, f(get(dict, map((x -> oftype(u, x[i])), zipslice), s)))
            end
            view(buffer, 1:n)
        end
    end
end

function Base.map(covariate::GroupStatsCovariate{N, U, S, T}, dataframe::AbstractDataFrame) where {T<:AbstractFloat} where {N} where {U} where {S}
    mapkeyvars = map(covariate.groupstats.keyvars) do v
        map(v, dataframe; permute = true)
    end
    gstats = GroupStats{N, U, S}(mapkeyvars, covariate.groupstats.covariate, covariate.groupstats.selector, covariate.groupstats.stats)
    GroupStatsCovariate{N, U, S, T}(covariate.name, length(dataframe), gstats, covariate.transform)
end
