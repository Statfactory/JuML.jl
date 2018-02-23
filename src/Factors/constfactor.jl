struct ConstFactor <: AbstractFactor{UInt8}
    name::String
    level::String
    length::Integer
end

Base.length(factor::ConstFactor) = factor.length

getlevels(factor::ConstFactor) = [factor.level]

function ConstFactor(length::Integer)
    ConstFactor("Intercept", "Intercept", length)
end

function slice(factor::ConstFactor, fromobs::Integer, toobs::Integer, slicelength::Integer)
    if fromobs > toobs
        EmptySeq{AbstractVector{UInt8}}()
    else
        fromobs = max(1, fromobs)
        toobs = min(toobs, length(factor))
        slicelength = verifyslicelength(fromobs, toobs, slicelength) 
        buffer = ones(UInt8, slicelength) 
        map(Seq(Tuple{Int64, Int64}, (fromobs, toobs, slicelength), nextslice), SubArray{UInt8,1,Array{UInt8,1},Tuple{UnitRange{Int64}},true}) do rng
            view(buffer, 1:(rng[2] - rng[1] + 1))
        end
    end
end

function Base.map(factor::ConstFactor, dataframe::AbstractDataFrame)
    ConstFactor(factor.name, factor.level, length(dataframe))
end