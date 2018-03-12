struct TransDateTimeCovariate{T<:AbstractFloat} <: AbstractCovariate{T}
    name::String
    basevariate::AbstractDateTimeVariate
    transform::Function
end

Base.length(var::TransDateTimeCovariate) = length(var.basevariate)

function TransDateTimeCovariate(name::String, basevariate::AbstractDateTimeVariate, transform::Function)
    TransDateTimeCovariate{Float32}(name, basevariate, transform)
end

function TransDateTimeCovariate(::Type{T}, name::String, basevariate::AbstractDateTimeVariate, transform::Function) where {T<:AbstractFloat} 
    TransDateTimeCovariate{T}(name, basevariate, transform)
end

function slice(covariate::TransDateTimeCovariate{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat} 
    basevar = covariate.basevariate
    f = covariate.transform
    g = (ms::Int64) -> begin
        ms == zero(Int64) ? T(NaN32) : begin
            dt = Dates.epochms2datetime(ms)
            convert(T, f(dt))
        end
    end
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = slice(basevar, fromobs, toobs, slicelength)
    mapslice(g, slices, slicelength, T)
end

function Base.map(covariate::TransDateTimeCovariate, dataframe::AbstractDataFrame)
    TransDateTimeCovariate(covariate.name, map(covariate.basevariate, dataframe), covariate.transform)
end

