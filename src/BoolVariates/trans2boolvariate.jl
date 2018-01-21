struct Trans2BoolVariate <: AbstractBoolVariate
    name::String
    baseboolvar1::AbstractBoolVariate
    baseboolvar2::AbstractBoolVariate
    transform::Function
end

Base.length(var::Trans2BoolVariate) = length(var.baseboolvar1)

function slice(boolvar::Trans2BoolVariate, fromobs::Integer, toobs::Integer, slicelength::Integer)
    baseboolvar1 = boolvar.baseboolvar1
    baseboolvar2 = boolvar.baseboolvar2
    f = boolvar.transform
    slices = zip2(slice(baseboolvar1, fromobs, toobs, slicelength), slice(baseboolvar2, fromobs, toobs, slicelength))
    mapslice2(f, slices, slicelength, Bool)
end