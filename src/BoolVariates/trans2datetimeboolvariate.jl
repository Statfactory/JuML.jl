struct Trans2DateTimeBoolVariate <: AbstractBoolVariate
    name::String
    basevariate1::AbstractDateTimeVariate
    basevariate2::AbstractDateTimeVariate
    transform::Function
end

Base.length(var::Trans2DateTimeBoolVariate) = length(var.basevariate1)

function slice(boolvar::Trans2DateTimeBoolVariate, fromobs::Integer, toobs::Integer, slicelength::Integer) 
    base1 = boolvar.basevariate1
    base2 = boolvar.basevariate2
    f = boolvar.transform
    g = (ms1::Int64, ms2::Int64) -> begin
        ms1 == zero(Int64) || ms2 == zero(Int64) ? false : begin
            dt1 = Dates.epochms2datetime(ms1)
            dt2 = Dates.epochms2datetime(ms2)
            f(dt1, dt2)
        end
    end
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = zip(slice(base1, fromobs, toobs, slicelength), slice(base2, fromobs, toobs, slicelength)) 
    mapslice2(g, slices, slicelength, Bool)
end