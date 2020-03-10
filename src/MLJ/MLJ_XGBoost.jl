import MLJBase
import DataFrames
import CategoricalArrays

mutable struct XGBClassifier <: MLJBase.Probabilistic
    maxdepth::Integer
    nrounds::Integer
 end 

function XGBClassifier(; maxdepth = 6, nrounds = 2)
    model = XGBClassifier(maxdepth, nrounds)
    return model
end

function MLJBase.scitypes(X::Vector{<:AbstractFactor})
    [MLJBase.Multiclass for x in X]
end

function MLJBase.scitype_union(y::AbstractFactor)
    MLJBase.Multiclass
end

function MLJBase.scitype_union(y::AbstractCovariate)
    MLJBase.Multiclass
end


function MLJBase.target_scitype_union(model::XGBClassifier)
    MLJBase.Multiclass
end

function MLJBase.selectrows(X::Vector{<:AbstractFactor}, r)
    (X, r)
end

function MLJBase.selectrows(X::JuML.DataFrame, r)
    (X, r)
end

function MLJBase.selectrows(y::AbstractFactor, r)
    (y, r)
end

function MLJBase.selectrows(y::AbstractCovariate, r)
    (y, r)
end

function MLJBase.fit(model::XGBClassifier, verbosity::Integer, X::DataFrames.DataFrame,
                     y::CategoricalArrays.CategoricalArray)
 
    X = JuML.DataFrame(X)
    levels = [string(level) for level in CategoricalArrays.index(y.pool)]
    T = eltype(y.refs)
    y = Factor{T}("y", levels, y.refs)
    label = covariate(y, (level -> level == levels[1] ? 1.0 : 0.0))
    trainsel = BoolVariate("", BitArray{1}(undef, 0))
    fitres = xgblogit(label, X.factors; trainselector = trainsel, maxdepth = model.maxdepth,
                      nrounds = model.nrounds)
    return fitres, nothing, nothing
end

function MLJBase.fit(model::XGBClassifier, verbosity::Integer, X::Tuple{Vector{<:AbstractFactor}, Any},
                     y::Tuple{AbstractCovariate, Any})

    trainsel = X[2] <: Colon ?
        begin
            BoolVariate("", BitArray{1}(undef, 0))
        end :
        begin
            n = length(y[1])
            b = falses(n) 
            for i in X[2]
                b[i] = true
            end
            BoolVariate("", b)
        end

    factors = X[1]
    label = y[1]
    fitres = xgblogit(label, factors; trainselector = trainsel, maxdepth = model.maxdepth,
                      nrounds = model.nrounds)
    return fitres, nothing, nothing

end

function MLJBase.fit(model::XGBClassifier, verbosity::Integer, X::Tuple{JuML.DataFrame, Any},
                     y::Tuple{AbstractCovariate, Any})

    factors = X[1].factors
    MLJBase.fit(model, verbosity, (factors, X[2]), y)
end

function MLJBase.fit(model::XGBClassifier, verbosity::Integer, X::Tuple{JuML.DataFrame, Any},
                     y::Tuple{AbstractFactor, Any})

    factors = X[1].factors
    ylevels = getlevels(y[1])
    label = covariate(getname(y), (level -> level == ylevels[1] ? 1.0 : 0.0))
    MLJBase.fit(model, verbosity, (factors, X[2]), (label, y[2]))

end

function MLJBase.predict(model::XGBClassifier, fitresult, Xnew::JuML.DataFrame)

    predict(fitresult, Xnew)
                         
end

function MLJBase.predict(model::XGBClassifier, fitresult, Xnew)

    predict(fitresult, JuML.DataFrame(Xnew))
                         
end

