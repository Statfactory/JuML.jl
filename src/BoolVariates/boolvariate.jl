struct BoolVariate <: AbstractBoolVariate
    name::String
    data::AbstractVector{Bool}
end

Base.length(boolvar::AbstractBoolVariate) = length(boolvar.data)

function slice(boolvar::BoolVariate, fromobs::Integer, toobs::Integer, slicelength::Integer)
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slice(boolvar.data, fromobs, toobs, slicelength)
end

