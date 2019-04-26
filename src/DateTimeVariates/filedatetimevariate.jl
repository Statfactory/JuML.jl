struct FileDateTimeVariate <: AbstractDateTimeVariate
    name::String
    length::Int64
    datapath::String
end

Base.length(dtvar::FileDateTimeVariate) = dtvar.length

function slice(dtvar::FileDateTimeVariate, fromobs::Integer, toobs::Integer, slicelength::Integer)
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    sizeT = sizeof(Int64)
    iostream = open(dtvar.datapath)
    seek(iostream, sizeT * (fromobs - 1))
    buffer = Vector{Int64}(undef, slicelength)
    map(Seq(Vector{Int64}, (buffer, iostream, fromobs, toobs, slicelength), nextdatachunk), SubArray{Int64,1,Array{Int64,1},Tuple{UnitRange{Int64}},true}) do slice
        view(slice, 1:length(slice))
    end
end

function Base.map(dtvar::FileDateTimeVariate, dataframe::AbstractDataFrame)
    dataframe[getname(dtvar)]
end