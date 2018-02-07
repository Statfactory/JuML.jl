struct BoolVarFactor <: AbstractFactor{UInt8}
    name::String
    boolvar::AbstractBoolVariate
end

getlevels(factor::BoolVarFactor) = ["True", "False"]

Base.length(var::BoolVarFactor) = length(var.boolvar)

function slice(factor::BoolVarFactor, fromobs::Integer, toobs::Integer, slicelength::Integer)
    f = (x::Bool -> x ? UInt8(1) : UInt8(2))
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = slice(factor.boolvar, fromobs, toobs, slicelength)
    mapslice(f, slices, slicelength, UInt8) 
end