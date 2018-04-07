struct Trans2CovBoolVariate{S<:AbstractFloat, T<:AbstractFloat} <: AbstractBoolVariate
    name::String
    basecovariate1::AbstractCovariate{S}
    basecovariate2::AbstractCovariate{T}
    transform::Function
end

Base.length(var::Trans2CovBoolVariate) = length(var.basecovariate1)

function slice(boolvar::Trans2CovBoolVariate{S, T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {S<:AbstractFloat} where {T<:AbstractFloat} 
    basecov1 = boolvar.basecovariate1
    basecov2 = boolvar.basecovariate2
    f = boolvar.transform
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = zip(slice(basecov1, fromobs, toobs, slicelength), slice(basecov2, fromobs, toobs, slicelength)) 
    mapslice2(f, slices, slicelength, Bool)
end
