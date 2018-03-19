struct BoolVariate <: AbstractBoolVariate
    name::String
    data::BitArray{1}
end

Base.length(boolvar::BoolVariate) = length(boolvar.data)

function slice(boolvar::BoolVariate, fromobs::Integer, toobs::Integer, slicelength::Integer)
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slice(boolvar.data, fromobs, toobs, slicelength)
end

