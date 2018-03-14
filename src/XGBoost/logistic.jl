function logit∂𝑙(y::AbstractFloat, ŷ::AbstractFloat)
    res = ŷ - y
    isnan(res) ? zero(res) : res
end

function logit∂²𝑙(ŷ::T) where {T<:AbstractFloat}
    res = max(ŷ * (one(T) - ŷ), eps(T))
    isnan(res) ? zero(T) : res
end

function logitraw(p::T) where {T<:AbstractFloat}
    -log(one(T) / p - one(T))
end

function logitraw(p::T, posweight::T) where {T<:AbstractFloat}
    -log(one(T) / p - one(T)) + log(posweight)
end

function sigmoid(x::T) where {T<:AbstractFloat}
    one(T) / (one(T) + exp(-x))
end

function logloss(y::AbstractFloat, ŷ::AbstractFloat)
    ϵ = eps(ŷ)
    if ŷ < ϵ
        -y * log(ϵ) - (one(y) - y)  * log(one(ϵ) - ϵ)
    elseif one(ŷ) - ŷ < ϵ
        -y * log(one(ϵ) - ϵ) - (one(y) - y)  * log(ϵ)
    else
        -y * log(ŷ) - (one(y) - y) * log(one(ŷ) - ŷ)
    end
end

function xgblogit(label::AbstractCovariate, factors::Vector{<:AbstractFactor};
                  selector::AbstractBoolVariate = BoolVariate("", BitArray{1}(0)), μ::Real = 0.5, posweight::Real = 1.0,
                  η::Real = 0.3, λ::Real = 1.0, γ::Real = 0.0, maxdepth::Integer = 6, nrounds::Integer = 2, ordstumps::Bool = false, pruning::Bool = true,
                  minchildweight::Real = 1.0, caching::Bool = true, slicelength::Integer = 0, usefloat64::Bool = false,
                  singlethread::Bool = false)

    T = usefloat64 ? Float64 : Float32
    factors = caching ? map(cache, widenfactors(filter((f -> getname(f) != getname(label)), factors))) : filter((f -> getname(f) != getname(label)), factors)
    label = caching ? cache(label) : label
    slicelength = slicelength <= 0 ? length(label) : slicelength
    λ = T(λ)
    γ = T(γ)
    η = T(η)
    posweight = T(posweight)
    minchildweight = T(minchildweight)
    μ = T(μ)
    f0 = Vector{T}(length(label))
    if posweight == one(T)
        fill!(f0, T(logitraw(μ)))
    else
        fill!(f0, T(logitraw(μ, posweight)))
    end
    zerocov = ConstCovariate(zero(T), length(selector))
    fm, trees = fold((f0, Vector{XGTree}()), Seq(1:nrounds)) do x, m
        fm, trees = x
        ŷ = Covariate(sigmoid.(fm)) 

        f = caching ? cache : identity

        ∂𝑙 = length(selector) == 0 ? Trans2Covariate(T, "∂𝑙", label, ŷ, logit∂𝑙) |> f : ifelse(selector, Trans2Covariate(T, "∂𝑙", label, ŷ, logit∂𝑙), zerocov)
        ∂²𝑙 = length(selector) == 0 ? TransCovariate(T, "∂²𝑙", ŷ, logit∂²𝑙) |> f : ifelse(selector, TransCovariate(T, "∂²𝑙", ŷ, logit∂²𝑙), zerocov)
        if posweight != one(T)
            ∂𝑙 = TransCovariate(T, "∂𝑙", ∂𝑙, x -> posweight * x)
            ∂²𝑙 = TransCovariate(T, "∂²𝑙", ∂²𝑙, x -> posweight * x)
        end
        ∂𝑙 = ∂𝑙 |> f
        ∂²𝑙 = ∂²𝑙 |> f

        tree, predraw = growtree(factors, ∂𝑙, ∂²𝑙, maxdepth, λ, γ, minchildweight, ordstumps, pruning, slicelength, singlethread)
        fm .= muladd.(η, predraw, fm)
        predraw .= sigmoid.(fm)
        @show m
        @show getauc(predraw, label)
        push!(trees, tree)
        (fm, trees)
    end
    fm .= sigmoid.(fm)
    XGModel{T}(trees, λ, γ, η, minchildweight, maxdepth, fm)
end

function cvxgblogit(label::AbstractCovariate, factors::Vector{<:AbstractFactor}, nfolds::Integer;
                    aucmetric::Bool = true, loglossmetric::Bool = true, trainmetric::Bool = false, μ::Real = 0.5,
                    η::Real = 0.3, λ::Real = 1.0, γ::Real = 0.0, maxdepth::Integer = 6, nrounds::Integer = 2, ordstumps::Bool = false, pruning::Bool = true,
                    minchildweight::Real = 1.0, caching::Bool = true, slicelength::Integer = 0, usefloat64::Bool = false,
                    singlethread::Bool = false)

    cvfolds = getnfolds(nfolds, false, length(label))
    trainaucfold = Vector{Float64}(nfolds)
    trainloglossfold = Vector{Float64}(nfolds)
    testaucfold = Vector{Float64}(nfolds)
    testloglossfold = Vector{Float64}(nfolds)
    for i in 1:nfolds
        trainselector = cvfolds .!= UInt8(i)
        testselector = cvfolds .== UInt8(i)
        model = xgblogit(label, factors; selector = BoolVariate("", trainselector), η = η, λ = λ, γ = γ, μ = μ, maxdepth = maxdepth,
                         nrounds = nrounds, ordstumps = ordstumps, pruning = pruning, minchildweight = minchildweight,
                         caching = caching, slicelength = slicelength, usefloat64 = usefloat64, singlethread = singlethread)
        if aucmetric
            testaucfold[i] = getauc(model.pred, label; selector = testselector)
            if trainmetric
                trainaucfold[i] = getauc(model.pred, label; selector = trainselector)
            end
        end
        if loglossmetric
            testloglossfold[i] = getlogloss(model.pred, label; selector = testselector)
            if trainmetric
                trainloglossfold[i] = getlogloss(model.pred, label; selector = trainselector)
            end
        end
    end
    res = Dict{String, Float64}()
    if aucmetric
        if trainmetric
            res["train_auc_mean"] = mean(trainaucfold)
            res["train_auc_std"] = std(trainaucfold)
        end
        res["test_auc_mean"] = mean(testaucfold)
        res["test_auc_std"] = std(testaucfold)
    end
    if loglossmetric
        if trainmetric
            res["train_logloss_mean"] = mean(trainloglossfold)
            res["train_logloss_std"] = std(trainloglossfold)
        end
        res["test_logloss_mean"] = mean(testloglossfold)
        res["test_logloss_std"] = std(testloglossfold)
    end
    res
end

function predict(model::XGModel{T}, dataframe::AbstractDataFrame; μ::Real = 0.5, posweight::Real = 1.0,) where {T<:AbstractFloat}
    trees = model.trees
    μ = T(μ)
    posweight = T(posweight)
    η = model.η
    f0 = Vector{T}(length(dataframe))
    if posweight == one(T)
        fill!(f0, T(logitraw(μ)))
    else
        fill!(f0, T(logitraw(μ, posweight)))
    end
    for tree in trees
        predraw = predict(tree, dataframe)
        f0 .= muladd.(η, predraw, f0)
    end
    f0 .= sigmoid.(f0)
    f0
end

function getauc(pred::Vector{T}, label::AbstractCovariate{S}; selector::AbstractBoolVariate = BoolVariate("", BitArray{1}()), slicelength::Integer = SLICELENGTH) where {T <: AbstractFloat} where {S <: AbstractFloat}
    labelslices = slice(label, 1, length(label), slicelength)
    sellen = length(selector) 

    len = sellen == 0 ? length(pred) : begin
        fold(0, slice(selector, 1, sellen, slicelength)) do acc, slice
            res = acc
            for v in slice
                if v    
                    res += 1
                end
            end
            res
        end
    end
    uniqcount = Dict{T, Int64}()
    labelagg = Dict{T, S}()

    if sellen == 0
        fold(0, labelslices) do offset, slice
            for i in 1:length(slice)
                v = pred[offset + i]
                uniqcount[v] = get(uniqcount, v, 0) + 1
                labelagg[v] = get(labelagg, v, zero(S)) + slice[i]
            end
            offset + length(slice)
        end
    else
        zipslices = zip2(labelslices, slice(selector, 1, sellen, slicelength))
        fold(0, zipslices) do offset, slice
            labelslice, selslice = slice
            for i in 1:length(labelslice)
                if !selslice[i]
                    continue
                end
                v = pred[offset + i]
                uniqcount[v] = get(uniqcount, v, 0) + 1
                labelagg[v] = get(labelagg, v, zero(S)) + labelslice[i]
            end
            offset + length(labelslice)
        end
    end

    uniqpred = collect(keys(uniqcount))
    sort!(uniqpred; rev = true)
    ucount = map((v -> uniqcount[v]), uniqpred)

    sumlabel = sum(values(labelagg))
    cumlabel = cumsum(map((p -> labelagg[p]), uniqpred))
    cumcount = cumsum(ucount)
    map!((x -> convert(S, x)), cumcount, cumcount)
    tpr = (cumlabel ./ sumlabel)
    fpr = ((cumcount .- cumlabel) ./ (len .- sumlabel))
    len = length(tpr)
    fpr1 = view(fpr, 1:(len-1))
    fpr2 = view(fpr, 2:len)
    tpr1 = view(tpr, 1:(len - 1))
    tpr2 = view(tpr, 2:len)
    area0 = fpr[1] * tpr[1] 
    0.5 * (sum((tpr1 .+ tpr2) .* (fpr2 .- fpr1)) + area0)
end

function getlogloss(pred::Vector{T}, label::AbstractCovariate{S}; selector::AbstractVector{Bool} = BitArray{1}()) where {T <: AbstractFloat} where {S <: AbstractFloat}
    label = convert(Vector{S}, label)
    label::Vector{S} = length(selector) == 0 ? label : label[selector]
    pred::Vector{T} = length(selector) == 0 ? pred : pred[selector]
    mean(logloss.(label, pred))
end