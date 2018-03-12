struct TransDateTimeBoolVariate <: AbstractBoolVariate
    name::String
    basevariate::AbstractDateTimeVariate
    transform::Function
end

Base.length(var::TransDateTimeBoolVariate) = length(var.basevariate)

function slice(variate::TransDateTimeBoolVariate, fromobs::Integer, toobs::Integer, slicelength::Integer) 
    basevar = variate.basevariate
    f = variate.transform
    g = (ms::Int64) -> begin
        ms == zero(Int64) ? false : begin
            dt = Dates.epochms2datetime(ms)
            f(dt)
        end
    end
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = slice(basevar, fromobs, toobs, slicelength)
    mapslice(g, slices, slicelength, Bool)
end