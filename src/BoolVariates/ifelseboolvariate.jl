struct IfElseBoolVariate <: AbstractBoolVariate
    name::String
    ifboolvar::AbstractBoolVariate
    trueboolvar::AbstractBoolVariate
    falseboolvar::AbstractBoolVariate
end

Base.length(var::IfElseBoolVariate) = length(var.ifboolvar)

function slice(boolvar::IfElseBoolVariate, fromobs::Integer, toobs::Integer, slicelength::Integer)
    ifboolvar = boolvar.ifboolvar
    trueboolvar = boolvar.trueboolvar
    falseboolvar = boolvar.falseboolvar
    f = ((x, y, z) -> x ? y : z)
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    slices = zip(slice(ifboolvar, fromobs, toobs, slicelength), slice(trueboolvar, fromobs, toobs, slicelength),
                  slice(falseboolvar, fromobs, toobs, slicelength)) 
    mapslice3(f, slices, slicelength) 
end

function Base.ifelse(ifboolvar::AbstractBoolVariate, trueboolvar::AbstractBoolVariate, falseboolvar::AbstractBoolVariate)
    IfElseBoolVariate("$(getname(ifboolvar))?$(getname(trueboolvar)):$(getname(falseboolvar))", ifboolvar, trueboolvar, falseboolvar)
end