struct FileCovariate{T<:AbstractFloat} <: AbstractCovariate{T}
    name::String
    length::Int64
    datapath::String
end

Base.length(covariate::FileCovariate{T}) where {T<:AbstractFloat} = covariate.length

function slice(covariate::FileCovariate{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat}
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    sizeT = sizeof(T)
    iostream = open(covariate.datapath, "r")
    seek(iostream, sizeT * (fromobs - 1))
    buffer = Vector{T}(undef, slicelength)
    map(Seq(Vector{T}, (buffer, iostream, fromobs, toobs, slicelength), nextdatachunk), SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}) do slice
        view(slice, 1:length(slice))
    end
end

function Base.map(covariate::FileCovariate, dataframe::AbstractDataFrame)
    dataframe[getname(covariate)]
end

