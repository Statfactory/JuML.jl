function logit∂𝑙(y::AbstractFloat, ŷ::AbstractFloat)
    ŷ - y
end

function logit∂²𝑙(ŷ::T) where {T<:AbstractFloat}
    max(ŷ * (one(T) - ŷ), eps(T))
end

function logitraw(p::T) where {T<:AbstractFloat}
    -log(one(T) / p - one(T))
end

function sigmoid(x::T) where {T<:AbstractFloat}
    one(T) / (one(T) + exp(-x))
end

function xgblogit(label::AbstractCovariate, factors::Vector{<:AbstractFactor};
                  η::Real = 0.3, λ::Real = 1.0, γ::Real = 0.0, maxdepth::Integer = 6, nrounds::Integer = 2,
                  minchildweight::Real = 1.0, caching::Bool = true, slicelength::Integer = 0,
                  singlethread::Bool = false)

    factors = caching ? map(cache, widenfactors(factors)) : factors
    label = caching ? cache(label) : label
    slicelength = slicelength <= 0 ? length(label) : slicelength
    λ = Float32(λ)
    γ = Float32(γ)
    η = Float32(η)
    minchildweight = Float32(minchildweight)
    μ = 0.5f0
    f0 = Vector{Float32}(length(label))
    fill!(f0, Float32(logitraw(μ)))
    fm, trees = fold((f0, Vector{Tree}()), Seq(1:nrounds)) do x, m
        fm, trees = x
        ŷ = Covariate(sigmoid.(fm))
        ∂𝑙 = Trans2Covariate("∂𝑙", label, ŷ, logit∂𝑙) |> cache
        ∂²𝑙 = TransCovariate("∂²𝑙", ŷ, logit∂²𝑙) |> cache
        tree, predraw = growtree(factors, ∂𝑙, ∂²𝑙, maxdepth, λ, γ, minchildweight, slicelength, singlethread)
        fm .= muladd.(η, predraw, fm)
        push!(trees, tree)
        (fm, trees)
    end
    pred = sigmoid.(fm)
    (trees, pred)
end

function predict(trees::Vector{Tree}, dataframe::AbstractDataFrame, η::Real)
    μ = 0.5f0
    η = Float32(η)
    f0 = Vector{Float32}(length(dataframe))
    fill!(f0, Float32(logitraw(μ)))  
    for tree in trees
        predraw = predict(tree, dataframe)
        f0 .= muladd.(η, predraw, f0)
    end
    sigmoid.(f0)
end