struct Trans2DateTimeVariate <: AbstractDateTimeVariate
    name::String
    basevariate1::AbstractDateTimeVariate
    basevariate2::AbstractDateTimeVariate
    transform::Function
end

Base.length(var::Trans2DateTimeVariate) = length(var.basevariate1)

function slice(dtvariate::Trans2DateTimeVariate, fromobs::Integer, toobs::Integer, slicelength::Integer)
    base1 = dtvariate.basevariate1
    base2 = dtvariate.basevariate2
    f = dtvariate.transform
    g = (ms1::Int64, ms2::Int64) -> begin
        dt1 = Dates.epochms2datetime(ms1)
        dt2 = Dates.epochms2datetime(ms2)
        Dates.datetime2epochms(f(dt1, dt2))
    end
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = zip(slice(base1, fromobs, toobs, slicelength), slice(base2, fromobs, toobs, slicelength)) 
    mapslice2(g, slices, slicelength, Int64)
end

function Base.map(dtvariate::Trans2DateTimeVariate, dataframe::AbstractDataFrame)
    Trans2DateTimeVariate(dtvariate.name, map(dtvariate.basevariate1, dataframe), map(dtvariate.basevariate1, dataframe),
                          dtvariate.transform)
end