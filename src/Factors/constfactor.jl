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

function slice(covariate::ConstFactor, fromobs::Integer, toobs::Integer, slicelength::Integer)
    if fromobs > toobs
        EmptySeq{AbstractVector{UInt8}}()
    else
        fromobs = max(1, fromobs)
        toobs = min(toobs, length(covariate))
        slicelength = min(max(1, slicelength), toobs - fromobs + 1)
        buffer = ones(UInt8, slicelength) 
        map(Seq(Tuple{Int64, Int64}, (fromobs, toobs, slicelength), nextslice), AbstractVector{UInt8}) do rng
            if rng[2] - rng[1] + 1 == slicelength
                buffer
            else
                view(buffer, 1:(rng[2] - rng[1] + 1))
            end
        end
    end
end