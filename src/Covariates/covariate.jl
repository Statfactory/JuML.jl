struct Covariate{T<:AbstractFloat} <: AbstractCovariate{T}
    name::String
    data::Vector{T}
end

Base.length(covariate::Covariate{T}) where {T<:AbstractFloat} = length(covariate.data)

function Covariate(data::AbstractVector{T}) where {T<:AbstractFloat}
    Covariate{T}("", data)
end

function Covariate(name::String, data::AbstractVector{T}) where {T<:Integer}
    Covariate{Float32}(name, convert(Vector{Float32}, data))
end

function Covariate(data::AbstractVector{T}) where {T<:Integer}
    Covariate{Float32}("", convert(Vector{Float32}, data))
end

function Covariate{T}(name::String, length::Integer, datpath::String) where {T<:AbstractFloat}
    data = Vector{T}(undef, length)
    open(datpath) do f
        read!(f, data)
    end
    Covariate{T}(name, data)
end

function slice(covariate::Covariate{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat}
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slice(covariate.data, fromobs, toobs, slicelength)
end

function Base.map(covariate::Covariate, dataframe::AbstractDataFrame)
    dataframe[getname(covariate)]
end