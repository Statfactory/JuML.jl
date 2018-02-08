struct FileFactor{T<:Unsigned} <: AbstractFactor{T}
    name::String
    length::Int64
    levels::AbstractVector{<:AbstractString}
    datapath::String
end

Base.length(factor::FileFactor{T}) where {T<:Unsigned} = factor.length

function slice(factor::FileFactor{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned}
    len = toobs - fromobs + 1
    data = Vector{UInt8}(sizeof(T) * len)
    open(factor.datapath) do f
        seek(f, sizeof(T) * (fromobs - 1))
        readbytes!(f, data)
    end
    factordata = reinterpret(T, data)
    slice(factordata, 1, len, slicelength)
end

function Base.map(factor::FileFactor, dataframe::AbstractDataFrame)
    PermuteFactor(factor, dataframe[getname(factor)])
end