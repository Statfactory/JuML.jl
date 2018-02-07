struct ConstCovariate{T<:AbstractFloat} <: AbstractCovariate{T}
    name::String
    length::Integer
    value::T
end

function ConstCovariate(value::T, length::Integer) where {T<:AbstractFloat}
    ConstCovariate{T}("", length, value)
end

Base.length(covariate::ConstCovariate{T}) where {T<:AbstractFloat} = covariate.length

function slice(covariate::ConstCovariate{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat}
    if fromobs > toobs
        EmptySeq{AbstractVector{T}}()
    else
        fromobs = max(1, fromobs)
        toobs = min(toobs, length(covariate))
        slicelength = verifyslicelength(fromobs, toobs, slicelength) 
        buffer = Vector{T}(slicelength)
        fill!(buffer, covariate.value)
        map(Seq(Tuple{Int64, Int64}, (fromobs, toobs, slicelength), nextslice), AbstractVector{T}) do rng
            if rng[2] - rng[1] + 1 == slicelength
                buffer
            else
                view(buffer, 1:(rng[2] - rng[1] + 1))
            end
        end
    end
end

function Base.map(covariate::ConstCovariate, dataframe::AbstractDataFrame)
    ConstCovariate(covariate.name, length(dataframe), covariate.value)
end