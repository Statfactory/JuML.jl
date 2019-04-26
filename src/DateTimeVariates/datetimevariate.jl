struct DateTimeVariate <: AbstractDateTimeVariate
    name::String
    data::AbstractVector{Int64}
end

Base.length(dt::DateTimeVariate) = length(dt.data)

function DateTimeVariate(data::AbstractVector{Int64}) 
    DateTimeVariate("", data)
end

function DateTimeVariate(name::String, length::Integer, datpath::String)
    data = Vector{Int64}(undef, length)
    open(datpath) do f
        read!(f, data)
    end
    DateTimeVariate(name, data)
end

function slice(dtvariate::DateTimeVariate, fromobs::Integer, toobs::Integer, slicelength::Integer)
    slicelength = verifyslicelength(fromobs, toobs, slicelength)  
    slice(dtvariate.data, fromobs, toobs, slicelength)
end

function Base.map(dtvariate::DateTimeVariate, dataframe::AbstractDataFrame)
    dataframe[getname(dtvariate)]
end
