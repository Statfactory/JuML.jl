struct IntVariate{T<:Signed} <: AbstractIntVariate{T}
    name::String
    data::Vector{T}
end

Base.length(intvariate::IntVariate{T}) where {T<:Signed} = length(intvariate.data)

function IntVariate{T}(name::String, length::Integer, datpath::String) where {T<:Signed}
    data = Vector{T}(undef, length)
    open(datpath) do f
        read!(f, data)
    end
    IntVariate{T}(name, data)
end

function slice(intvariate::IntVariate{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Signed}
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slice(intvariate.data, fromobs, toobs, slicelength)
end

function Base.map(intvariate::IntVariate, dataframe::AbstractDataFrame; permute::Bool = false)
    dataframe[getname(intvariate)]
end

