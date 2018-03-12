struct TransDateTimeVariate <: AbstractDateTimeVariate
    name::String
    basevariate::AbstractDateTimeVariate
    transform::Function
end

Base.length(var::TransDateTimeVariate) = length(var.basevariate)

function slice(dtvariate::TransDateTimeVariate, fromobs::Integer, toobs::Integer, slicelength::Integer) 
    basevar = dtvariate.basevariate
    f = dtvariate.transform
    g = (ms::Int64) -> begin
        dt = Dates.epochms2datetime(ms)
        Dates.datetime2epochms(f(dt))
    end
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = slice(basevar, fromobs, toobs, slicelength)
    mapslice(g, slices, slicelength, Int64)
end

function Base.map(dtvariate::TransDateTimeVariate, dataframe::AbstractDataFrame)
    TransDateTimeVariate(dtvariate.name, map(dtvariate.basevariate, dataframe), dtvariate.transform)
end

function datetimevariate(f, basevariate::AbstractDateTimeVariate) 
    TransDateTimeVariate("$(f)($(getname(basevariate)))", basevariate, f)
end

# function Base.broadcast(f, basevariate::AbstractDateTimeVariate) 
#     if typeof(f(zero(Int64))) <: AbstractFloat
#         TransCovariate("$(f)($(getname(basecovariate)))", basecovariate, f)
#     else
#         TransCovBoolVariate{S}("$(f)($(getname(basecovariate)))", basecovariate, f) 
#     end
# end