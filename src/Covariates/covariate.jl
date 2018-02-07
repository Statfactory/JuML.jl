struct Covariate{T<:AbstractFloat} <: AbstractCovariate{T}
    name::String
    data::AbstractVector{T}
end

Base.length(covariate::AbstractCovariate{T}) where {T<:AbstractFloat} = length(covariate.data)

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
    data = Vector{UInt8}(sizeof(T) * length)
    open(datpath) do f
        readbytes!(f, data)
    end
    covdata = reinterpret(T, data)
    Covariate{T}(name, covdata)
end

function slice(covariate::Covariate{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat}
    slice(covariate.data, fromobs, toobs, slicelength)
end

function Base.map(covariate::Covariate, dataframe::AbstractDataFrame)
    dataframe[getname(covariate)]
end