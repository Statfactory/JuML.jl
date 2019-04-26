struct IfElseCovariate{S<:AbstractFloat, T<:AbstractFloat, U<:AbstractFloat} <: AbstractCovariate{U}
    name::String
    ifboolvar::AbstractBoolVariate
    truecovariate::AbstractCovariate{S}
    falsecovariate::AbstractCovariate{T}
end

Base.length(var::IfElseCovariate) = length(var.ifboolvar)
 
function IfElseCovariate(name::String, ifboolvar::AbstractBoolVariate, truecovariate::AbstractCovariate{S}, falsecovariate::AbstractCovariate{T}) where {S<:AbstractFloat} where {T<:AbstractFloat} 
    U = promote_type(S, T)
    IfElseCovariate{S, T, U}(name, ifboolvar, truecovariate, falsecovariate)
end

function IfElseCovariate(ifboolvar::AbstractBoolVariate, truecovariate::AbstractCovariate{S}, falsecovariate::AbstractCovariate{T}) where {S<:AbstractFloat} where {T<:AbstractFloat} 
    IfElseCovariate("", ifboolvar, truecovariate, falsecovariate)
end
 
function slice(cov::IfElseCovariate{S, T, U}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {S<:AbstractFloat} where {T<:AbstractFloat} where {U<:AbstractFloat}
    ifboolvar = cov.ifboolvar
    truecov = cov.truecovariate
    falsecov = cov.falsecovariate
    f = ((x, y, z) -> x ? y : z)
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = zip(slice(ifboolvar, fromobs, toobs, slicelength), slice(truecov, fromobs, toobs, slicelength),
                 slice(falsecov, fromobs, toobs, slicelength)) 
    mapslice3(f, slices, slicelength, U)
end

function iif(ifboolvar::AbstractBoolVariate, truecovariate::AbstractCovariate{S}, falsecovariate::AbstractCovariate{T}) where {S<:AbstractFloat} where{T<:AbstractFloat}
    IfElseCovariate("$(getname(ifboolvar))?$(getname(truecovariate)):$(getname(falsecovariate))", ifboolvar, truecovariate, falsecovariate)
end