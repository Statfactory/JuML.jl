mutable struct GroupStatsCovariate{N, T<:AbstractFloat} <: AbstractCovariate{T}
    name::String
    length::Int64
    groupstats::GroupStats{N}
    transform::Function
end

function GroupStatsCovariate(name::String, groupstats::GroupStats{N}, transform::Function) where {N}
    GroupStatsCovariate{N, Float32}(name, length(groupstats.keyvars[1]), groupstats, transform)
end

function GroupStatsCovariate(name::String, groupstats::GroupStats{N}) where {N}
    GroupStatsCovariate{N, Float32}(name, length(groupstats.keyvars[1]), groupstats, identity)
end

function GroupStatsCovariate(::Type{T}, name::String, groupstats::GroupStats{N}, transform::Function) where {T<:AbstractFloat} where {N}
    GroupStatsCovariate{N, T}(name, length(groupstats.keyvars[1]), groupstats, transform)
end

function GroupStatsCovariate(::Type{T}, name::String, groupstats::GroupStats{N}) where {T<:AbstractFloat} where {N}
    GroupStatsCovariate{N, T}(name, length(groupstats.keyvars[1]), groupstats, identity)
end

function slice(covariate::GroupStatsCovariate{N, T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat} where {N}
    keyvars = covariate.groupstats.keyvars
    eltypes = map((x -> eltype(x)), keyvars)
    dict = covariate.groupstats.stats
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    zipslices = zipn(map((v -> slice(v, fromobs, toobs, slicelength)), keyvars))
    f = covariate.transform
    buffer = Vector{T}(slicelength)
    map(zipslices, SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}) do zipslice
        n = length(zipslice[1])
        if N == 2
            slice1, slice2 = zipslice
            for i in 1:n
                buffer[i] = T(f(dict[(slice1[i], slice2[i])]))
            end
            view(buffer, 1:n)
        else
            for i in 1:n
                buffer[i] = T(f(dict[map((x -> x[i]), zipslice)]))
            end
            view(buffer, 1:n)
        end
    end
end
