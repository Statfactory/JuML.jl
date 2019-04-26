struct RandCovariate <: AbstractCovariate{Float32}
    name::String
    length::Integer
end

function RandCovariate(length::Integer) 
    RandCovariate("", length)
end

Base.length(covariate::RandCovariate) = covariate.length

function slice(covariate::RandCovariate, fromobs::Integer, toobs::Integer, slicelength::Integer) 
    if fromobs > toobs
        EmptySeq{SubArray{Float32,1,Array{Float32,1},Tuple{UnitRange{Int64}},true}}()
    else
        fromobs = max(1, fromobs)
        toobs = min(toobs, length(covariate))
        slicelength = verifyslicelength(fromobs, toobs, slicelength) 
        buffer = Vector{Float32}(undef, slicelength)
        map(Seq(Tuple{Int64, Int64}, (fromobs, toobs, slicelength), nextslice), SubArray{Float32,1,Array{Float32,1},Tuple{UnitRange{Int64}},true}) do rng
            rand!(buffer)
            view(buffer, 1:(rng[2] - rng[1] + 1))
        end
    end
end