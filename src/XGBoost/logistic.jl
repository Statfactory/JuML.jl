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
                  minchildweight::Real = 1.0, caching::Bool = true, slicelength::Integer = 0, usefloat64::Bool = false,
                  singlethread::Bool = false)

    T = usefloat64 ? Float64 : Float32
    factors = caching ? map(cache, widenfactors(filter((f -> getname(f) != getname(label)), factors))) : filter((f -> getname(f) != getname(label)), factors)
    label = caching ? cache(label) : label
    slicelength = slicelength <= 0 ? length(label) : slicelength
    λ = T(λ)
    γ = T(γ)
    η = T(η)
    minchildweight = T(minchildweight)
    μ = T(0.5f0)
    f0 = Vector{T}(length(label))
    fill!(f0, T(logitraw(μ)))
    fm, trees = fold((f0, Vector{Tree}()), Seq(1:nrounds)) do x, m
        fm, trees = x
        ŷ = Covariate(sigmoid.(fm))
        ∂𝑙 = Trans2Covariate(T, "∂𝑙", label, ŷ, logit∂𝑙) |> cache
        ∂²𝑙 = TransCovariate(T, "∂²𝑙", ŷ, logit∂²𝑙) |> cache
        tree, predraw = growtree(factors, ∂𝑙, ∂²𝑙, maxdepth, λ, γ, minchildweight, slicelength, singlethread)
        fm .= muladd.(η, predraw, fm)
        push!(trees, tree)
        (fm, trees)
    end
    pred = sigmoid.(fm)
    XGModel{T}(trees, λ, γ, η, minchildweight, maxdepth, pred)
end

function predict(model::XGModel{T}, dataframe::AbstractDataFrame) where {T<:AbstractFloat}
    trees = model.trees
    μ = T(0.5f0)
    η = model.η
    f0 = Vector{T}(length(dataframe))
    fill!(f0, T(logitraw(μ)))  
    for tree in trees
        predraw = predict(tree, dataframe)
        f0 .= muladd.(η, predraw, f0)
    end
    sigmoid.(f0)
end

function getauc(pred::Vector{T}, label::AbstractCovariate{S}) where {T <: AbstractFloat} where {S <: AbstractFloat}
    label = convert(Vector{S}, label)
    perm = sortperm(pred; rev = true)
    sum_auc = 0.0
    sum_pospair = 0.0
    sum_npos = 0.0
    sum_nneg = 0.0
    buf_pos = 0.0
    buf_neg = 0.0
    for i in 1:length(pred)
        p = pred[perm[i]]
        r = label[perm[i]]
        if i != 1 && p != pred[perm[i - 1]]
            sum_pospair = sum_pospair +  buf_neg * (sum_npos + buf_pos * 0.5)
            sum_npos = sum_npos + buf_pos
            sum_nneg = sum_nneg + buf_neg
            buf_neg = 0.0
            buf_pos = 0.0
        end
        buf_pos = buf_pos + r 
        buf_neg = buf_neg + (1.0 - r)
    end
    sum_pospair = sum_pospair + buf_neg * (sum_npos + buf_pos * 0.5)
    sum_npos = sum_npos + buf_pos
    sum_nneg = sum_nneg + buf_neg
    sum_auc = sum_auc + sum_pospair / (sum_npos * sum_nneg)
    sum_auc 
end