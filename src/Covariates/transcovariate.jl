struct TransCovariate{S<:AbstractFloat, T<:AbstractFloat} <: AbstractCovariate{T}
    name::String
    basecovariate::AbstractCovariate{S}
    transform::Function
end

Base.length(var::TransCovariate) = length(var.basecovariate)

function TransCovariate(name::String, basecovariate::AbstractCovariate{T}, transform::Function) where {T<:AbstractFloat}
    TransCovariate{T, T}(name, basecovariate, transform)
end

function TransCovariate(::Type{T}, name::String, basecovariate::AbstractCovariate{S}, transform::Function) where {T<:AbstractFloat} where {S<:AbstractFloat}
    TransCovariate{S, T}(name, basecovariate, transform)
end

function slice(covariate::TransCovariate{S, T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat} where {S<:AbstractFloat}
    basecov = covariate.basecovariate
    f = covariate.transform
    slices = slice(basecov, fromobs, toobs, slicelength)
    mapslice(f, slices, slicelength, T)
end

function covariate(name::String, transform::Function)
    basecov::AbstractCovariate ->
        TransCovariate(name, basecov, transform)
end

function Base.map(covariate::TransCovariate, dataframe::AbstractDataFrame)
    TransCovariate(covariate.name, map(covariate.basecovariate, dataframe), covariate.transform)
end