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
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = slice(basecov, fromobs, toobs, slicelength)
    mapslice(f, slices, slicelength, T)
end

function Base.map(covariate::TransCovariate, dataframe::AbstractDataFrame)
    TransCovariate(covariate.name, map(covariate.basecovariate, dataframe), covariate.transform)
end

function covariate(f, basecovariate::AbstractCovariate{S}) where {S<:AbstractFloat}
    TransCovariate("$(f)($(getname(basecovariate)))", basecovariate, f)
end

function Base.sqrt(basecovariate::AbstractCovariate{S}) where {S<:AbstractFloat}
    covariate(sqrt, basecovariate)
end

function Base.log(basecovariate::AbstractCovariate{S}) where {S<:AbstractFloat}
    covariate(log, basecovariate)
end

function Base.broadcast(f, basecovariate::AbstractCovariate{S}) where {S<:AbstractFloat}  
    if typeof(f(zero(S))) <: AbstractFloat
        TransCovariate("$(f)($(getname(basecovariate)))", basecovariate, f)
    else
        TransCovBoolVariate{S}("$(f)($(getname(basecovariate)))", basecovariate, f) 
    end
end