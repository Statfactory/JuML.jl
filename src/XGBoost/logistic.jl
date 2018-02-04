function logit∂𝑙(y::Real, ŷ::Real)
    ŷ - y
end

function logit∂²𝑙(ŷ::Real)
    max(ŷ * (1.0 - ŷ), eps())
end

function logitraw(p::Real)
    -log(1.0 / p - 1.0)
end

function sigmoid(x::Real)
    1.0 / (1.0 + exp(-x))
end

function xgblogit(label::AbstractCovariate, factors::Vector{<:AbstractFactor};
                  η::Real = 0.3, λ::Real = 1.0, γ::Real = 0.0, maxdepth::Integer = 6, nrounds::Integer = 2,
                  minchildweight::Real = 1.0, slicelength::Integer = SLICELENGTH)

    μ = 0.5
    f0 = Vector{Float64}(length(label))
    fill!(f0, logitraw(μ))
    fm, trees = fold((f0, Vector{Tree}()), Seq(1:nrounds)) do x, m
        fm, trees = x
        ŷ = Covariate(sigmoid.(fm))
        ∂𝑙 = CachedCovariate(Trans2Covariate("∂𝑙", label, ŷ, logit∂𝑙))
        ∂²𝑙 = CachedCovariate(TransCovariate("∂²𝑙", ŷ, logit∂²𝑙))
        tree, predraw = growtree(factors, ∂𝑙, ∂²𝑙, maxdepth, λ, γ, minchildweight, slicelength)
        fm .= muladd.(η, predraw, fm)
        push!(trees, tree)
        (fm, trees)
    end
    pred = sigmoid.(fm)
    (trees, pred)
end

function predict(trees::Vector{Tree}, dataframe::AbstractDataFrame, η::Real)
    μ = 0.5
    f0 = Vector{Float64}(length(dataframe))
    fill!(f0, logitraw(μ))  
    for tree in trees
        predraw = predict(tree, dataframe)
        f0 .= muladd.(η, predraw, f0)
    end
    sigmoid.(f0)
end