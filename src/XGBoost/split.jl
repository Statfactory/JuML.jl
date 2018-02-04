
function getweight(gradient::LossGradient, λ::Real) 
    -gradient.∂𝑙 / (gradient.∂²𝑙 + λ)
end

function getloss(∂𝑙::Real, ∂²𝑙::Real, λ::Real, γ::Real)
    -0.5 * ∂𝑙 * ∂𝑙 / (∂²𝑙 + λ) + γ
end

function getloss(node::LeafNode, λ::Real, γ::Real)
    ∂𝑙 = node.gradient.∂𝑙
    ∂²𝑙 = node.gradient.∂²𝑙
    getloss(∂𝑙, ∂²𝑙, λ, γ)
end

function getloss(node::SplitNode, λ::Real, γ::Real)
    node.loss
end

function sumgradient(nodeids::Vector{<:Integer}, nodecansplit::Vector{Bool}, factor::AbstractFactor, partitions::Vector{LevelPartition},
                     ∂𝑙covariate::AbstractCovariate, ∂²𝑙covariate::AbstractCovariate, slicelength::Integer)
    
    nodecount = length(nodecansplit)
    levelcounts = [p.inclmissing ? length(p.mask) + 1 : length(p.mask) for p in partitions]
    inclmiss = [p.inclmissing for p in partitions]
    ∂𝑙sum0 = [(nodecansplit[node] ? [0.0 for i in 1:(levelcounts[node])] : Vector{Float64}()) for node in 1:nodecount]
    ∂²𝑙sum0 = [(nodecansplit[node] ? [0.0 for i in 1:(levelcounts[node])] : Vector{Float64}()) for node in 1:nodecount]

    fromobs = 1
    toobs = length(nodeids)
    nodeslices = slice(nodeids, fromobs, toobs, slicelength)
    factorslices = slice(factor, fromobs, toobs, slicelength)
    ∂𝑙slices = slice(∂𝑙covariate, fromobs, toobs, slicelength)
    ∂²𝑙slices = slice(∂²𝑙covariate, fromobs, toobs, slicelength)
    zipslices = zip4(nodeslices, factorslices, ∂𝑙slices, ∂²𝑙slices)
    fold((∂𝑙sum0, ∂²𝑙sum0), zipslices) do gradsum, zipslice
        nodeslice, factorslice, ∂𝑙slice, ∂²𝑙slice = zipslice
        ∂𝑙sum, ∂²𝑙sum = gradsum
        for i in 1:length(nodeslice)
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
    [(nodecansplit[node] ? [LossGradient(∂𝑙sum0[node][i], ∂²𝑙sum0[node][i]) for i in 1:(levelcounts[node])] : Vector{LossGradient}()) for node in 1:nodecount]
end

function splitnodeids!(nodeids::Vector{<:Integer}, layer::TreeLayer, slicelength::Integer)
    nodes = layer.nodes
    nodecount = length(nodes)
    len = length(nodeids)
    issplitnode = [isa(n, SplitNode) for n in nodes]
    intercept = ConstFactor(len)
    factors = widenfactors([isa(n, LeafNode) ? intercept : n.factor for n in nodes])
    leftpartitions = [isa(n, SplitNode) ? n.leftpartition : LevelPartition(Vector{Bool}(), false)  for n in nodes]
    factorslices = zipn([slice(factor, 1, len, slicelength) for factor in factors])
    nodeslices = slice(nodeids, 1, len, slicelength)
    foreach(zip2(nodeslices, factorslices)) do x
        nodeslice, fslices = x
        for (i, nodeid) in enumerate(nodeslice)
            if nodeid > 0
                if issplitnode[nodeid]
                    levelindex = fslices[nodeid][i]
                    leftpartition = leftpartitions[nodeid]
                    misswithleft = leftpartition.inclmissing
                    if levelindex > length(leftpartition.mask)
                        nodeslice[i] = 0
                    else
                        nodeslice[i] = (levelindex == 0 && misswithleft) || leftpartition.mask[levelindex] ? (2 * nodeslice[i] - 1) : (2 * nodeslice[i]) 
                    end
                else
                    nodeslice[i] = 2 * nodeslice[i] - 1
                end
            end
        end
    end
    nodeids
end

function getsplitnode(factor::AbstractFactor, partition::LevelPartition, gradient::Vector{LossGradient},
                      λ::Real, γ::Real, min∂²𝑙::Real)

    inclmiss = partition.inclmissing
    gradstart = inclmiss ? 2 : 1
    ∂𝑙sum0 = sum((grad -> grad.∂𝑙), gradient[gradstart:end])
    ∂²𝑙sum0 = sum((grad -> grad.∂²𝑙), gradient[gradstart:end]) 
    miss∂𝑙 = inclmiss ? gradient[1].∂𝑙 : 0.0
    miss∂²𝑙 = inclmiss ? gradient[1].∂²𝑙 : 0.0
    bestloss = getloss(∂𝑙sum0 + miss∂𝑙, ∂²𝑙sum0 + miss∂²𝑙, λ, γ)
    levelcount = length(partition.mask)
    split = SplitNode(factor, partition, LevelPartition(zeros(Bool, levelcount), false),
                      LossGradient(∂𝑙sum0 + miss∂𝑙, ∂²𝑙sum0 + miss∂²𝑙), LossGradient(0.0, 0.0),
                      bestloss)
    
    left∂𝑙sum = gradient[gradstart].∂𝑙
    left∂²𝑙sum = gradient[gradstart].∂²𝑙

    firstlevelwithmiss = getloss(left∂𝑙sum + miss∂𝑙, left∂²𝑙sum + miss∂²𝑙, λ, γ) + getloss(∂𝑙sum0 - left∂𝑙sum, ∂²𝑙sum0 - left∂²𝑙sum, λ, γ)
    firstlevelwitouthmiss = getloss(left∂𝑙sum, left∂²𝑙sum, λ, γ) + getloss(∂𝑙sum0 - left∂𝑙sum + miss∂𝑙, ∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙, λ, γ)

    if firstlevelwithmiss < bestloss && (left∂²𝑙sum + miss∂²𝑙 >= min∂²𝑙) && (∂²𝑙sum0 - left∂²𝑙sum >= min∂²𝑙)
        if firstlevelwitouthmiss < firstlevelwithmiss && (left∂²𝑙sum >= min∂²𝑙) && (∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙 >= min∂²𝑙)
            split.leftgradient = LossGradient(left∂𝑙sum, left∂²𝑙sum)
            split.rightgradient = LossGradient(∂𝑙sum0 - left∂𝑙sum + miss∂𝑙, ∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙)
            split.leftpartition = LevelPartition([j == 1 for j in 1:levelcount], false)
            split.rightpartition = LevelPartition([j == 1 ? false : partition.mask[j] for j in 1:levelcount], partition.inclmissing)
            split.loss = firstlevelwitouthmiss
        else
            split.leftgradient = LossGradient(left∂𝑙sum + miss∂𝑙, left∂²𝑙sum + miss∂²𝑙)
            split.rightgradient = LossGradient(∂𝑙sum0 - left∂𝑙sum, ∂²𝑙sum0 - left∂²𝑙sum)
            split.leftpartition = LevelPartition([j == 1 for j in 1:levelcount], partition.inclmissing)
            split.rightpartition = LevelPartition([j == 1 ? false : partition.mask[j] for j in 1:levelcount], partition.inclmissing)
            split.loss = firstlevelwithmiss
        end
    end

    for i in 2:(levelcount - 1)
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

        if singlelevelwithmisstotal < split.loss && (∂²𝑙 + miss∂²𝑙 >= min∂²𝑙) && (∂²𝑙sum0 - ∂²𝑙 >= min∂²𝑙)
            if singlelevelwitouthmisstotal < singlelevelwithmisstotal && (∂²𝑙 >= min∂²𝑙) && (∂²𝑙sum0 - ∂²𝑙 + miss∂²𝑙 >= min∂²𝑙)
                split.leftgradient = LossGradient(∂𝑙, ∂²𝑙)
                split.rightgradient = LossGradient(∂𝑙sum0 - ∂𝑙 + miss∂𝑙, ∂²𝑙sum0 - ∂²𝑙 + miss∂²𝑙)
                split.leftpartition = LevelPartition([j == i for j in 1:levelcount], false)
                split.rightpartition = LevelPartition([j == i ? false : partition.mask[j] for j in 1:levelcount], partition.inclmissing)
                split.loss = singlelevelwitouthmisstotal
            else
                split.leftgradient = LossGradient(∂𝑙 + miss∂𝑙, ∂²𝑙 + miss∂²𝑙)
                split.rightgradient = LossGradient(∂𝑙sum0 - ∂𝑙, ∂²𝑙sum0 - ∂²𝑙)
                split.leftpartition = LevelPartition([j == i for j in 1:levelcount], partition.inclmissing)
                split.rightpartition = LevelPartition([j == i ? false : partition.mask[j] for j in 1:levelcount], partition.inclmissing)
                split.loss = singlelevelwithmisstotal
            end
        end

        if leftwithmisstotal < split.loss && (left∂²𝑙sum + miss∂²𝑙 >= min∂²𝑙) && (∂²𝑙sum0 - left∂²𝑙sum >= min∂²𝑙)
            if leftwithoutmisstotal < leftwithmisstotal && (left∂²𝑙sum >= min∂²𝑙) && (∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙 >= min∂²𝑙)
                split.leftgradient = LossGradient(left∂𝑙sum, left∂²𝑙sum)
                split.rightgradient = LossGradient(∂𝑙sum0 - left∂𝑙sum + miss∂𝑙, ∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙)
                split.leftpartition = LevelPartition([(j <= i) ? partition.mask[j] : false for j in 1:levelcount], false)
                split.rightpartition = LevelPartition([j <= i ? false : partition.mask[j] for j in 1:levelcount], partition.inclmissing)
                split.loss = leftwithoutmisstotal
            else
                split.leftgradient = LossGradient(left∂𝑙sum + miss∂𝑙, left∂²𝑙sum + miss∂²𝑙)
                split.rightgradient = LossGradient(∂𝑙sum0 - left∂𝑙sum, ∂²𝑙sum0 - left∂²𝑙sum)
                split.leftpartition = LevelPartition([(j <= i) ? partition.mask[j] : false for j in 1:levelcount], partition.inclmissing)
                split.rightpartition = LevelPartition([j <= i ? false : partition.mask[j] for j in 1:levelcount], partition.inclmissing)
                split.loss = leftwithmisstotal
            end
        end
    end
    if count(split.rightpartition.mask) > 0
        Nullable{SplitNode}(split)
    else
        Nullable{SplitNode}()
    end
end

function findbestsplit(nodeids::Vector{<:Integer}, nodes::Vector{TreeNode}, factors::Vector{<:AbstractFactor},
                       ∂𝑙covariate::AbstractCovariate, ∂²𝑙covariate::AbstractCovariate,
                       λ::Real, γ::Real, min∂²𝑙::Real, slicelength::Integer)

    foldl(nodes, enumerate(factors)) do currsplit, nfactor
        n, factor = nfactor
        partitions = [node.partitions[factor] for node in nodes]
        nodecansplit = [n.cansplit for n in nodes]
        gradient = sumgradient(nodeids, nodecansplit, factor, partitions, ∂𝑙covariate, ∂²𝑙covariate, slicelength)
        newsplit = map(enumerate(gradient)) do x
            i, grad = x
            if nodes[i].cansplit
                partition = nodes[i].partitions[factor]
                if count(partition.mask) > 1
                    getsplitnode(factor, nodes[i].partitions[factor],  grad, λ, γ, min∂²𝑙)
                else
                    Nullable{SplitNode}()
                end
            else
                Nullable{SplitNode}()
            end
        end
        res = Vector{TreeNode}(length(newsplit))
        for i in 1:length(newsplit)
             if !isnull(newsplit[i]) && get(newsplit[i]).loss < getloss(currsplit[i], λ, γ) 
                res[i] = get(newsplit[i])  
             else
                res[i] = currsplit[i] 
             end
        end
        res
    end
end

function updatestate(state::TreeGrowState, layer::TreeLayer)
    splitnodeids!(state.nodeids, layer, state.slicelength)  
    factors = state.factors
    newnodes = Vector{LeafNode}(2 * length(state.nodes))
    for (i, n) in enumerate(layer.nodes)
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
            newnodes[2 * i - 1] = LeafNode(n.leftgradient,
                                           n.leftgradient.∂²𝑙 >= state.min∂²𝑙,
                                           leftpartitions)
            newnodes[2 * i] = LeafNode(n.rightgradient,
                                       n.rightgradient.∂²𝑙 >= state.min∂²𝑙,
                                       rightpartitions)
        else
            newnodes[2 * i - 1] = LeafNode(n.gradient, false, n.partitions)
            newnodes[2 * i] = LeafNode(n.gradient, false, n.partitions)
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

function nextlayer(state::TreeGrowState)
    layernodes = findbestsplit(state.nodeids, state.nodes, state.factors,
                               state.∂𝑙covariate, state.∂²𝑙covariate, state.λ,
                               state.γ, state.min∂²𝑙, state.slicelength)
    layer = TreeLayer(layernodes)
    updatestate(state, layer)
    Nullable{TreeLayer}(layer), state      
end

function predict(treelayer::TreeLayer, nodeids::Vector{<:Integer}, λ)
    weights = Vector{Float64}(2 * length(treelayer.nodes))
    for (i, node) in enumerate(treelayer.nodes)
        if isa(node, SplitNode)
            weights[2 * i - 1] = getweight(node.leftgradient, λ)
            weights[2 * i] = getweight(node.rightgradient, λ)
        else
            weights[2 * i - 1] = getweight(node.gradient, λ)
            weights[2 * i] = getweight(node.gradient, λ)
        end
    end
    (nodeid -> nodeid > 0 ? weights[nodeid] : NaN64).(nodeids)
end

function predict(tree::Tree, dataframe::AbstractDataFrame)
    len = length(dataframe)
    maxnodecount = 2 ^ tree.maxdepth
    nodeids = maxnodecount <= typemax(UInt8) ? ones(UInt8, len) : (maxnodecount <= typemax(UInt16) ? ones(UInt16, len) : ones(UInt32, len))
    nodes = Vector{TreeNode}()
    for layer in tree.layers
        nodes = [isa(n, SplitNode) ? SplitNode(map(n.factor, dataframe), n.leftpartition, n.rightpartition, n.leftgradient, n.rightgradient, n.loss) : n for n in layer.nodes]
        splitnodeids!(nodeids, TreeLayer(nodes), tree.slicelength)
    end
    predict(TreeLayer(nodes), nodeids, tree.λ)
end

function growtree(factors::Vector{<:AbstractFactor}, ∂𝑙covariate::AbstractCovariate,
                  ∂²𝑙covariate::AbstractCovariate, maxdepth::Integer, λ::Real, γ::Real,
                  min∂²𝑙::Real, slicelength::Integer)

    len = length(∂𝑙covariate)
    maxnodecount = 2 ^ maxdepth
    nodeids = maxnodecount <= typemax(UInt8) ? ones(UInt8, len) : (maxnodecount <= typemax(UInt16) ? ones(UInt16, len) : ones(UInt32, len))
    intercept = ConstFactor(len)
    grad0 = sumgradient(nodeids, [true], intercept, [LevelPartition([true], false)], ∂𝑙covariate, ∂²𝑙covariate, slicelength)[1][1]
    nodes0 = Vector{TreeNode}()
    push!(nodes0, LeafNode(grad0, true, Dict([f => LevelPartition(ones(Bool, length(getlevels(f))), true) for f in factors])))
    state0 = TreeGrowState(nodeids, nodes0, factors, ∂𝑙covariate, ∂²𝑙covariate, λ, γ, min∂²𝑙, slicelength)
    layers = collect(Iterators.take(Seq(TreeLayer, state0, nextlayer), maxdepth))
    tree = Tree(layers, λ, γ, min∂²𝑙, maxdepth, slicelength)
    pred = predict(tree.layers[end], nodeids, λ)
    tree, pred
end

