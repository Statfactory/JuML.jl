
function getweight(gradient::LossGradient{T}, λ::T) where {T<:AbstractFloat} 
    -gradient.∂𝑙 / (gradient.∂²𝑙 + λ)
end

function getloss(∂𝑙::T, ∂²𝑙::T, λ::T, γ::T) where {T<:AbstractFloat} 
    -0.5 * ∂𝑙 * ∂𝑙 / (∂²𝑙 + λ) + γ
end

function getloss(node::LeafNode{T}, λ::T, γ::T) where {T<:AbstractFloat} 
    ∂𝑙 = node.gradient.∂𝑙
    ∂²𝑙 = node.gradient.∂²𝑙
    getloss(∂𝑙, ∂²𝑙, λ, γ)
end

function getloss(node::SplitNode{T}, λ::T, γ::T) where {T<:AbstractFloat} 
    node.loss
end

function sumgradientslice!(∂𝑙sum0, ∂²𝑙sum0, nodeids::Vector{<:Integer}, nodecansplit::Vector{Bool}, factor::AbstractFactor, inclmiss::Vector{Bool},
                           ∂𝑙covariate::AbstractCovariate, ∂²𝑙covariate::AbstractCovariate, fromobs::Integer, toobs::Integer, slicelength::Integer)

    nodeslices = slice(nodeids, fromobs, toobs, slicelength)
    factorslices = slice(factor, fromobs, toobs, slicelength)
    ∂𝑙slices = slice(∂𝑙covariate, fromobs, toobs, slicelength)
    ∂²𝑙slices = slice(∂²𝑙covariate, fromobs, toobs, slicelength)
    zipslices = zip4(nodeslices, factorslices, ∂𝑙slices, ∂²𝑙slices)
    fold((∂𝑙sum0, ∂²𝑙sum0), zipslices) do gradsum, zipslice
        nodeslice, factorslice, ∂𝑙slice, ∂²𝑙slice = zipslice
        ∂𝑙sum, ∂²𝑙sum = gradsum
        @inbounds for i in 1:length(nodeslice)
            nodeid = nodeslice[i]
            if nodecansplit[nodeid]
                levelindex = factorslice[i]
                if levelindex == 0
                    ∂𝑙sum[nodeid][1] += ∂𝑙slice[i]
                    ∂²𝑙sum[nodeid][1] += ∂²𝑙slice[i]
                elseif inclmiss[nodeid]
                    ∂𝑙sum[nodeid][levelindex + 1] += ∂𝑙slice[i]
                    ∂²𝑙sum[nodeid][levelindex + 1] += ∂²𝑙slice[i]
                else
                    ∂𝑙sum[nodeid][levelindex] += ∂𝑙slice[i]
                    ∂²𝑙sum[nodeid][levelindex] += ∂²𝑙slice[i]
                end
            end
        end
        (∂𝑙sum, ∂²𝑙sum)
    end
end

function sumgradient(nodeids::Vector{<:Integer}, nodecansplit::Vector{Bool}, factor::AbstractFactor, partitions::Vector{LevelPartition},
                     ∂𝑙covariate::AbstractCovariate{T}, ∂²𝑙covariate::AbstractCovariate{T}, slicelength::Integer, singlethread::Bool) where {T<:AbstractFloat}
    
    nodecount = length(nodecansplit)
    levelcounts = [p.inclmissing ? length(p.mask) + 1 : length(p.mask) for p in partitions]
    inclmiss = [p.inclmissing for p in partitions]
    fromobs = 1
    toobs = length(nodeids)

    nthreads = singlethread ? 1 : Threads.nthreads()
    threadspace = map((x -> Int64(floor(x))), LinSpace(fromobs, toobs, nthreads + 1))
    ∂𝑙sum = [[(nodecansplit[node] ? [zero(T) for i in 1:(levelcounts[node])] : Vector{T}()) for node in 1:nodecount] for i in 1:nthreads]
    ∂²𝑙sum = [[(nodecansplit[node] ? [zero(T) for i in 1:(levelcounts[node])] : Vector{T}()) for node in 1:nodecount] for i in 1:nthreads]

    if nthreads > 1
        Threads.@threads for i in 1:nthreads
            sumgradientslice!(∂𝑙sum[i], ∂²𝑙sum[i], nodeids, nodecansplit, factor, inclmiss,
                            ∂𝑙covariate, ∂²𝑙covariate, threadspace[i],
                            i == nthreads ? threadspace[i + 1] : threadspace[i + 1] - 1, slicelength)
        end
        ∂𝑙sum = reduce(+, ∂𝑙sum)
        ∂²𝑙sum = reduce(+, ∂²𝑙sum)
        [(nodecansplit[node] ? [LossGradient{T}(∂𝑙sum[node][i], ∂²𝑙sum[node][i]) for i in 1:(levelcounts[node])] : Vector{LossGradient{T}}()) for node in 1:nodecount]
    else
        sumgradientslice!(∂𝑙sum[1], ∂²𝑙sum[1], nodeids, nodecansplit, factor, inclmiss,
                          ∂𝑙covariate, ∂²𝑙covariate, fromobs, toobs, slicelength)
        [(nodecansplit[node] ? [LossGradient{T}(∂𝑙sum[1][node][i], ∂²𝑙sum[1][node][i]) for i in 1:(levelcounts[node])] : Vector{LossGradient{T}}()) for node in 1:nodecount]
    end
end

function splitnodeidsslice!(nodeids::Vector{<:Integer}, factors, issplitnode::Vector{Bool},
                            leftpartitions::Vector{LevelPartition}, levelcounts::Vector{Int64}, factorindex::Vector{Int64},
                            fromobs::Integer, toobs::Integer, slicelength::Integer)
    if length(factors) == 0
        for i in fromobs:toobs
            nodeids[i] = 2 * nodeids[i] - 1
        end
    else
        factorslices = zipn([slice(factor, fromobs, toobs, slicelength) for factor in factors])
        nodeslices = slice(nodeids, fromobs, toobs, slicelength)
        foreach(zip2(nodeslices, factorslices)) do x
            nodeslice, fslices = x
            @inbounds for i in 1:length(nodeslice)
                nodeid = nodeslice[i]
                if nodeid > 0
                    if issplitnode[nodeid]
                        levelindex = fslices[factorindex[nodeid]][i]
                        if levelindex > levelcounts[nodeid]
                            nodeslice[i] = 0
                        else
                            leftpartition = leftpartitions[nodeid]
                            misswithleft = leftpartition.inclmissing
                            nodeslice[i] = (levelindex == 0 && misswithleft) || leftpartition.mask[levelindex] ? (2 * nodeslice[i] - 1) : (2 * nodeslice[i]) 
                        end
                    else
                        nodeslice[i] = 2 * nodeslice[i] - 1
                    end
                end
            end
        end
    end
end

function splitnodeids!(nodeids::Vector{<:Integer}, layer::TreeLayer{T}, slicelength::Integer, singlethread::Bool) where {T<:AbstractFloat}
    nodes = layer.nodes
    nodecount = length(nodes)
    len = length(nodeids)
    fromobs = 1
    toobs = len
    issplitnode = [isa(n, SplitNode) for n in nodes]
    factors = Vector{AbstractFactor}()
    factorindex = Vector{Int64}(nodecount)
    for i in 1:nodecount
         if issplitnode[i]
             factor = nodes[i].factor
             index = findfirst(factors, factor)
             if index == 0
                 push!(factors, factor)
             end
             factorindex[i] = findfirst(factors, factor)
         end
    end
    factors = widenfactors(factors)
    leftpartitions = [isa(n, SplitNode) ? n.leftpartition : LevelPartition(Vector{Bool}(), false)  for n in nodes]
    levelcounts = [length(p.mask) for p in leftpartitions]

    nthreads = singlethread ? 1 : Threads.nthreads()
    if nthreads > 1
        threadspace = map((x -> Int64(floor(x))), LinSpace(fromobs, toobs, nthreads + 1))
        Threads.@threads for j in 1:nthreads
             splitnodeidsslice!(nodeids, factors, issplitnode, leftpartitions, levelcounts, factorindex,
                                threadspace[j],
                                j == nthreads ? threadspace[j + 1] : (threadspace[j + 1] - 1), slicelength)
        end
    else
        splitnodeidsslice!(nodeids, factors, issplitnode, leftpartitions, levelcounts, factorindex,
                           fromobs, toobs, slicelength)
    end
    nodeids
end

function getsplitnode(factor::AbstractFactor, partition::LevelPartition, gradient::Vector{LossGradient{T}},
                      λ::T, γ::T, min∂²𝑙::T) where {T<:AbstractFloat}

    inclmiss = partition.inclmissing
    isord = isordinal(factor)
    gradstart = inclmiss ? 2 : 1
    ∂𝑙sum0 = sum((grad -> grad.∂𝑙), gradient[gradstart:end])
    ∂²𝑙sum0 = sum((grad -> grad.∂²𝑙), gradient[gradstart:end]) 
    miss∂𝑙 = inclmiss ? gradient[1].∂𝑙 : zero(T)
    miss∂²𝑙 = inclmiss ? gradient[1].∂²𝑙 :zero(T)
    bestloss = getloss(∂𝑙sum0 + miss∂𝑙, ∂²𝑙sum0 + miss∂²𝑙, λ, γ)
    levelcount = length(partition.mask)
    split = SplitNode{T}(factor, partition, LevelPartition(zeros(Bool, levelcount), false),
                         LossGradient{T}(∂𝑙sum0 + miss∂𝑙, ∂²𝑙sum0 + miss∂²𝑙), LossGradient{T}(zero(T), zero(T)),
                         bestloss)
    
    left∂𝑙sum = gradient[gradstart].∂𝑙
    left∂²𝑙sum = gradient[gradstart].∂²𝑙

    firstlevelwithmiss = getloss(left∂𝑙sum + miss∂𝑙, left∂²𝑙sum + miss∂²𝑙, λ, γ) + getloss(∂𝑙sum0 - left∂𝑙sum, ∂²𝑙sum0 - left∂²𝑙sum, λ, γ)
    firstlevelwitouthmiss = getloss(left∂𝑙sum, left∂²𝑙sum, λ, γ) + getloss(∂𝑙sum0 - left∂𝑙sum + miss∂𝑙, ∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙, λ, γ)

    if firstlevelwithmiss < bestloss && (left∂²𝑙sum + miss∂²𝑙 >= min∂²𝑙) && (∂²𝑙sum0 - left∂²𝑙sum >= min∂²𝑙)
        if firstlevelwitouthmiss < firstlevelwithmiss && (left∂²𝑙sum >= min∂²𝑙) && (∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙 >= min∂²𝑙)
            split.leftgradient = LossGradient{T}(left∂𝑙sum, left∂²𝑙sum)
            split.rightgradient = LossGradient{T}(∂𝑙sum0 - left∂𝑙sum + miss∂𝑙, ∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙)
            split.leftpartition = LevelPartition([j == 1 for j in 1:levelcount], false)
            split.rightpartition = LevelPartition([j == 1 ? false : partition.mask[j] for j in 1:levelcount], partition.inclmissing)
            split.loss = firstlevelwitouthmiss
        else
            split.leftgradient = LossGradient{T}(left∂𝑙sum + miss∂𝑙, left∂²𝑙sum + miss∂²𝑙)
            split.rightgradient = LossGradient{T}(∂𝑙sum0 - left∂𝑙sum, ∂²𝑙sum0 - left∂²𝑙sum)
            split.leftpartition = LevelPartition([j == 1 for j in 1:levelcount], partition.inclmissing)
            split.rightpartition = LevelPartition([j == 1 ? false : partition.mask[j] for j in 1:levelcount], partition.inclmissing)
            split.loss = firstlevelwithmiss
        end
    end

    @inbounds for i in 2:(levelcount - 1)
        if !partition.mask[i]
            continue
        end
        ∂𝑙 = gradient[i + gradstart - 1].∂𝑙
        ∂²𝑙 = gradient[i + gradstart - 1].∂²𝑙

        singlelevelwithmisstotal = getloss(∂𝑙 + miss∂𝑙, ∂²𝑙 + miss∂²𝑙, λ, γ) + getloss(∂𝑙sum0 - ∂𝑙, ∂²𝑙sum0 - ∂²𝑙, λ, γ)
        singlelevelwitouthmisstotal = getloss(∂𝑙, ∂²𝑙, λ, γ) + getloss(∂𝑙sum0 - ∂𝑙 + miss∂𝑙, ∂²𝑙sum0 - ∂²𝑙 + miss∂²𝑙, λ, γ)

        left∂𝑙sum += ∂𝑙
        left∂²𝑙sum += ∂²𝑙

        leftwithmisstotal = getloss(left∂𝑙sum + miss∂𝑙, left∂²𝑙sum + miss∂²𝑙, λ, γ) + getloss(∂𝑙sum0 - left∂𝑙sum, ∂²𝑙sum0 - left∂²𝑙sum, λ, γ)
        leftwithoutmisstotal = getloss(left∂𝑙sum, left∂²𝑙sum, λ, γ) + getloss(∂𝑙sum0 - left∂𝑙sum + miss∂𝑙, ∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙, λ, γ)

        if isord
            if leftwithmisstotal < split.loss && (left∂²𝑙sum + miss∂²𝑙 >= min∂²𝑙) && (∂²𝑙sum0 - left∂²𝑙sum >= min∂²𝑙)
                if leftwithoutmisstotal < leftwithmisstotal && (left∂²𝑙sum >= min∂²𝑙) && (∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙 >= min∂²𝑙)
                    split.leftgradient = LossGradient{T}(left∂𝑙sum, left∂²𝑙sum)
                    split.rightgradient = LossGradient{T}(∂𝑙sum0 - left∂𝑙sum + miss∂𝑙, ∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙)
                    split.leftpartition = LevelPartition([(j <= i) ? partition.mask[j] : false for j in 1:levelcount], false)
                    split.rightpartition = LevelPartition([j <= i ? false : partition.mask[j] for j in 1:levelcount], partition.inclmissing)
                    split.loss = leftwithoutmisstotal
                else
                    split.leftgradient = LossGradient{T}(left∂𝑙sum + miss∂𝑙, left∂²𝑙sum + miss∂²𝑙)
                    split.rightgradient = LossGradient{T}(∂𝑙sum0 - left∂𝑙sum, ∂²𝑙sum0 - left∂²𝑙sum)
                    split.leftpartition = LevelPartition([(j <= i) ? partition.mask[j] : false for j in 1:levelcount], partition.inclmissing)
                    split.rightpartition = LevelPartition([j <= i ? false : partition.mask[j] for j in 1:levelcount], partition.inclmissing)
                    split.loss = leftwithmisstotal
                end
            end
        else
            if singlelevelwithmisstotal < split.loss && (∂²𝑙 + miss∂²𝑙 >= min∂²𝑙) && (∂²𝑙sum0 - ∂²𝑙 >= min∂²𝑙)
                if singlelevelwitouthmisstotal < singlelevelwithmisstotal && (∂²𝑙 >= min∂²𝑙) && (∂²𝑙sum0 - ∂²𝑙 + miss∂²𝑙 >= min∂²𝑙)
                    split.leftgradient = LossGradient{T}(∂𝑙, ∂²𝑙)
                    split.rightgradient = LossGradient{T}(∂𝑙sum0 - ∂𝑙 + miss∂𝑙, ∂²𝑙sum0 - ∂²𝑙 + miss∂²𝑙)
                    split.leftpartition = LevelPartition([j == i for j in 1:levelcount], false)
                    split.rightpartition = LevelPartition([j == i ? false : partition.mask[j] for j in 1:levelcount], partition.inclmissing)
                    split.loss = singlelevelwitouthmisstotal
                else
                    split.leftgradient = LossGradient{T}(∂𝑙 + miss∂𝑙, ∂²𝑙 + miss∂²𝑙)
                    split.rightgradient = LossGradient{T}(∂𝑙sum0 - ∂𝑙, ∂²𝑙sum0 - ∂²𝑙)
                    split.leftpartition = LevelPartition([j == i for j in 1:levelcount], partition.inclmissing)
                    split.rightpartition = LevelPartition([j == i ? false : partition.mask[j] for j in 1:levelcount], partition.inclmissing)
                    split.loss = singlelevelwithmisstotal
                end
            end
        end
    end
    if count(split.rightpartition.mask) > 0
        Nullable{SplitNode{T}}(split)
    else
        Nullable{SplitNode{T}}()
    end
end

function getnewsplit(gradient::Vector{Vector{LossGradient{T}}}, nodes::Vector{TreeNode{T}}, factor::AbstractFactor,
                     λ::T, γ::T, min∂²𝑙::T, singlethread::Bool) where {T<:AbstractFloat}
    newsplit = Vector{Nullable{SplitNode{T}}}(length(gradient))
    if !singlethread
        Threads.@threads for i in 1:length(gradient)
            grad = gradient[i]
            if nodes[i].cansplit
                partition = nodes[i].partitions[factor]
                if count(partition.mask) > 1
                    newsplit[i] = getsplitnode(factor, nodes[i].partitions[factor],  grad, λ, γ, min∂²𝑙)
                else
                    newsplit[i] = Nullable{SplitNode{T}}()
                end
            else
                newsplit[i] = Nullable{SplitNode{T}}()
            end         
        end
    else
        for i in 1:length(gradient)
            grad = gradient[i]
            if nodes[i].cansplit
                partition = nodes[i].partitions[factor]
                if count(partition.mask) > 1
                    newsplit[i] = getsplitnode(factor, nodes[i].partitions[factor],  grad, λ, γ, min∂²𝑙)
                else
                    newsplit[i] = Nullable{SplitNode{T}}()
                end
            else
                newsplit[i] = Nullable{SplitNode{T}}()
            end         
        end
    end
    newsplit
end 

function findbestsplit(state::TreeGrowState{T}) where {T<:AbstractFloat}

    nodecansplit = [n.cansplit for n in state.nodes]
    foldl(state.nodes, enumerate(state.factors)) do currsplit, nfactor
        n, factor = nfactor
        partitions = [node.partitions[factor] for node in state.nodes]

        gradient = sumgradient(state.nodeids, nodecansplit, factor, partitions, state.∂𝑙covariate, state.∂²𝑙covariate, state.slicelength, state.singlethread)
        
        newsplit = getnewsplit(gradient, state.nodes, factor, state.λ, state.γ, state.min∂²𝑙, state.singlethread)

        res = Vector{TreeNode{T}}(length(newsplit))
        for i in 1:length(newsplit)
             if !isnull(newsplit[i]) && get(newsplit[i]).loss < getloss(currsplit[i], state.λ, state.γ) 
                res[i] = get(newsplit[i])  
             else
                res[i] = currsplit[i] 
             end
        end
        res
    end
end

function updatestate(state::TreeGrowState{T}, layer::TreeLayer{T}) where {T<:AbstractFloat}
    splitnodeids!(state.nodeids, layer, state.slicelength, state.singlethread)  
    factors = state.factors
    newnodes = Vector{LeafNode{T}}(2 * length(state.nodes))
    @inbounds for (i, n) in enumerate(layer.nodes)
        if isa(n, SplitNode)
            leftpartitions = map(state.nodes[i].partitions) do x
                f, p = x
                if f == n.factor
                    f => n.leftpartition
                else
                    x
                end
            end
            rightpartitions = map(state.nodes[i].partitions) do x
                f, p = x
                if f == n.factor
                    f => n.rightpartition
                else
                    x
                end
            end
            newnodes[2 * i - 1] = LeafNode{T}(n.leftgradient,
                                              n.leftgradient.∂²𝑙 >= state.min∂²𝑙,
                                              leftpartitions)
            newnodes[2 * i] = LeafNode{T}(n.rightgradient,
                                          n.rightgradient.∂²𝑙 >= state.min∂²𝑙,
                                          rightpartitions)
        else
            newnodes[2 * i - 1] = LeafNode{T}(n.gradient, false, n.partitions)
            newnodes[2 * i] = LeafNode{T}(n.gradient, false, n.partitions)
        end
    end
    activefactors = filter(factors) do f
        any(map((n -> count(n.partitions[f].mask) > 1), newnodes))
    end 
    state.factors = activefactors
    for n in newnodes
        n.partitions = filter(n.partitions) do f, p
            f in activefactors
        end
    end
    state.nodes = newnodes
    state
end

function nextlayer(state::TreeGrowState{T}) where {T<:AbstractFloat}
    layernodes = findbestsplit(state)
    layer = TreeLayer{T}(layernodes)
    updatestate(state, layer)
    Nullable{TreeLayer{T}}(layer), state      
end

function predict(treelayer::TreeLayer{T}, nodeids::Vector{<:Integer}, λ::T) where {T<:AbstractFloat}
    weights = Vector{T}(2 * length(treelayer.nodes))
    @inbounds for (i, node) in enumerate(treelayer.nodes)
        if isa(node, SplitNode)
            weights[2 * i - 1] = getweight(node.leftgradient, λ)
            weights[2 * i] = getweight(node.rightgradient, λ)
        else
            weights[2 * i - 1] = getweight(node.gradient, λ)
            weights[2 * i] = getweight(node.gradient, λ)
        end
    end
    (nodeid -> nodeid > 0 ? weights[nodeid] : T(NaN32)).(nodeids)
end

function predict(tree::Tree{T}, dataframe::AbstractDataFrame) where {T<:AbstractFloat}
    len = length(dataframe)
    maxnodecount = 2 ^ tree.maxdepth
    nodeids = maxnodecount <= typemax(UInt8) ? ones(UInt8, len) : (maxnodecount <= typemax(UInt16) ? ones(UInt16, len) : ones(UInt32, len))
    nodes = Vector{TreeNode{T}}()
    factormap = Dict{AbstractFactor, AbstractFactor}()
    for layer in tree.layers
        for node in layer.nodes
            if isa(node, SplitNode) && !(node.factor in keys(factormap))
                factormap[node.factor] = map(node.factor, dataframe) |> cache
            end
        end
    end

    for layer in tree.layers
        nodes = [isa(n, SplitNode) ? SplitNode{T}(factormap[n.factor], n.leftpartition, n.rightpartition, n.leftgradient, n.rightgradient, n.loss) : n for n in layer.nodes]
        splitnodeids!(nodeids, TreeLayer{T}(nodes), tree.slicelength, tree.singlethread)
    end
    predict(TreeLayer{T}(nodes), nodeids, tree.λ)
end

function growtree(factors::Vector{<:AbstractFactor}, ∂𝑙covariate::AbstractCovariate{T},
                  ∂²𝑙covariate::AbstractCovariate{T}, maxdepth::Integer, λ::T, γ::T,
                  min∂²𝑙::T, slicelength::Integer, singlethread::Bool) where {T<:AbstractFloat}

    len = length(∂𝑙covariate)
    maxnodecount = 2 ^ maxdepth
    nodeids = maxnodecount <= typemax(UInt8) ? ones(UInt8, len) : (maxnodecount <= typemax(UInt16) ? ones(UInt16, len) : ones(UInt32, len))
    intercept = ConstFactor(len)
    grad0 = sumgradient(nodeids, [true], intercept, [LevelPartition([true], false)], ∂𝑙covariate, ∂²𝑙covariate, slicelength, singlethread)[1][1]
    nodes0 = Vector{TreeNode{T}}()
    push!(nodes0, LeafNode{T}(grad0, true, Dict([f => LevelPartition(ones(Bool, length(getlevels(f))), true) for f in factors])))
    state0 = TreeGrowState{T}(nodeids, nodes0, factors, ∂𝑙covariate, ∂²𝑙covariate, λ, γ, min∂²𝑙, slicelength, singlethread)
    layers = collect(Iterators.take(Seq(TreeLayer{T}, state0, nextlayer), maxdepth))
    tree = Tree{T}(layers, λ, γ, min∂²𝑙, maxdepth, slicelength, singlethread)
    pred = predict(tree.layers[end], nodeids, λ)
    tree, pred
end

