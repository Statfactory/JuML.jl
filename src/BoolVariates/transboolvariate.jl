struct TransBoolVariate <: AbstractBoolVariate
    name::String
    baseboolvar::AbstractBoolVariate
    transform::Function
end

Base.length(var::TransBoolVariate) = length(var.baseboolvar)

function slice(boolvar::TransBoolVariate, fromobs::Integer, toobs::Integer, slicelength::Integer)
    baseboolvar = boolvar.baseboolvar
    f = boolvar.transform
    slices = slice(baseboolvar, fromobs, toobs, slicelength)
    mapslice(f, slices, slicelength, Bool)
end
