struct UnixDateCovariate <: AbstractCovariate{Float64}
    name::String
    datetimevar::AbstractDateTimeVariate
end

Base.length(var::UnixDateCovariate) = length(var.datetimevar)

function UnixDateCovariate(datetimevar::AbstractDateTimeVariate)
    UnixDateCovariate(getname(datetimevar), datetimevar)
end

function slice(unixdtcov::UnixDateCovariate, fromobs::Integer, toobs::Integer, slicelength::Integer)
    basevar = unixdtcov.datetimevar
    f = (tick::Int64) -> tick == zero(Int64) ? NaN64 : Dates.datetime2unix(Dates.epochms2datetime(tick))
    slicelength = verifyslicelength(fromobs, toobs, slicelength)  
    slices = slice(basevar, fromobs, toobs, slicelength)
    mapslice(f, slices, slicelength, Float64)
end

function Base.map(unixdtcov::UnixDateCovariate, dataframe::AbstractDataFrame)
    UnixDateCovariate(unixdtcov.name, map(unixdtcov.datetimevar, dataframe))
end

function covariate(datetimevar::AbstractDateTimeVariate)
    UnixDateCovariate(getname(datetimevar), datetimevar)
end

