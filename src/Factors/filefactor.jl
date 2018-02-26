struct FileFactor{T<:Unsigned} <: AbstractFactor{T}
    name::String
    length::Int64
    levels::AbstractVector{<:AbstractString}
    datapath::String
end

Base.length(factor::FileFactor{T}) where {T<:Unsigned} = factor.length

function slice(factor::FileFactor{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned}
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    sizeT = sizeof(T)
    iostream = open(factor.datapath)
    seek(iostream, sizeT * (fromobs - 1))
    buffer = Vector{T}(slicelength)
    map(Seq(Vector{T}, (buffer, iostream, fromobs, toobs, slicelength), nextdatachunk), SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}) do slice
        view(slice, 1:length(slice))
    end
    
    # len = toobs - fromobs + 1
    # slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    # data = Vector{UInt8}(sizeof(T) * len)
    # open(factor.datapath) do f
    #     seek(f, sizeof(T) * (fromobs - 1))
    #     readbytes!(f, data)
    # end
    # factordata = reinterpret(T, data)
    # slice(factordata, 1, len, slicelength)
end

function Base.map(factor::FileFactor, dataframe::AbstractDataFrame)
    dataframe[getname(factor)]
end