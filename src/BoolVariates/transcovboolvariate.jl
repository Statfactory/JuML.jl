struct TransCovBoolVariate{T<:AbstractFloat} <: AbstractBoolVariate
    name::String
    basecovariate::AbstractCovariate{T}
    transform::Function
end

Base.length(var::TransCovBoolVariate) = length(var.basecovariate)

function slice(covariate::TransCovBoolVariate{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat}
    basecov = covariate.basecovariate
    f = covariate.transform
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = slice(basecov, fromobs, toobs, slicelength)
    mapslice(f, slices, slicelength, Bool)
end
