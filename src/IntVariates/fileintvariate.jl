struct FileIntVariate{T<:Signed} <: AbstractIntVariate{T}
    name::String
    length::Int64
    datapath::String
end

Base.length(intvariate::FileIntVariate{T}) where {T<:Signed} = intvariate.length

function slice(intvariate::FileIntVariate{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Signed}
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    sizeT = sizeof(T)
    iostream = open(intvariate.datapath)
    seek(iostream, sizeT * (fromobs - 1))
    buffer = Vector{T}(undef, slicelength)
    map(Seq(Vector{T}, (buffer, iostream, fromobs, toobs, slicelength), nextdatachunk), SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}) do slice
        view(slice, 1:length(slice))
    end
end

function Base.map(intvariate::FileIntVariate, dataframe::AbstractDataFrame; permute::Bool = false)
    dataframe[getname(intvariate)]
end