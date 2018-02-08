
function getweight(gradient::LossGradient, λ::Float32) 
    -gradient.∂𝑙 / (gradient.∂²𝑙 + λ)
end

function getloss(∂𝑙::Float32, ∂²𝑙::Float32, λ::Float32, γ::Float32)
    -0.5 * ∂𝑙 * ∂𝑙 / (∂²𝑙 + λ) + γ
end

function getloss(node::LeafNode, λ::Float32, γ::Float32)
    ∂𝑙 = node.gradient.∂𝑙
    ∂²𝑙 = node.gradient.∂²𝑙
    getloss(∂𝑙, ∂²𝑙, λ, γ)
end

function getloss(node::SplitNode, λ::Float32, γ::Float32)
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
                     ∂𝑙covariate::AbstractCovariate, ∂²𝑙covariate::AbstractCovariate, slicelength::Integer, singlethread::Bool)
    
    nodecount = length(nodecansplit)
    levelcounts = [p.inclmissing ? length(p.mask) + 1 : length(p.mask) for p in partitions]
    inclmiss = [p.inclmissing for p in partitions]
    fromobs = 1
    toobs = length(nodeids)

    nthreads = singlethread ? 1 : Threads.nthreads()
    threadspace = map((x -> Int64(floor(x))), LinSpace(fromobs, toobs, nthreads + 1))
    ∂𝑙sum = [[(nodecansplit[node] ? [0.0f0 for i in 1:(levelcounts[node])] : Vector{Float32}()) for node in 1:nodecount] for i in 1:nthreads]
    ∂²𝑙sum = [[(nodecansplit[node] ? [0.0f0 for i in 1:(levelcounts[node])] : Vector{Float32}()) for node in 1:nodecount] for i in 1:nthreads]

    if nthreads > 1
        Threads.@threads for i in 1:nthreads
            sumgradientslice!(∂𝑙sum[i], ∂²𝑙sum[i], nodeids, nodecansplit, factor, inclmiss,
                            ∂𝑙covariate, ∂²𝑙covariate, threadspace[i],
                            i == nthreads ? threadspace[i + 1] : threadspace[i + 1] - 1, slicelength)
        end
        ∂𝑙sum = reduce(+, ∂𝑙sum)
        ∂²𝑙sum = reduce(+, ∂²𝑙sum)
        [(nodecansplit[node] ? [LossGradient(∂𝑙sum[node][i], ∂²𝑙sum[node][i]) for i in 1:(levelcounts[node])] : Vector{LossGradient}()) for node in 1:nodecount]
    else
        sumgradientslice!(∂𝑙sum[1], ∂²𝑙sum[1], nodeids, nodecansplit, factor, inclmiss,
                          ∂𝑙covariate, ∂²𝑙covariate, fromobs, toobs, slicelength)
        [(nodecansplit[node] ? [LossGradient(∂𝑙sum[1][node][i], ∂²𝑙sum[1][node][i]) for i in 1:(levelcounts[node])] : Vector{LossGradient}()) for node in 1:nodecount]
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

function splitnodeids!(nodeids::Vector{<:Integer}, layer::TreeLayer, slicelength::Integer, singlethread::Bool)
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

function getsplitnode(factor::AbstractFactor, partition::LevelPartition, gradient::Vector{LossGradient},
                      λ::Float32, γ::Float32, min∂²𝑙::Float32)

    inclmiss = partition.inclmissing
    gradstart = inclmiss ? 2 : 1
    ∂𝑙sum0 = sum((grad -> grad.∂𝑙), gradient[gradstart:end])
    ∂²𝑙sum0 = sum((grad -> grad.∂²𝑙), gradient[gradstart:end]) 
    miss∂𝑙 = inclmiss ? gradient[1].∂𝑙 : 0.0
    miss∂²𝑙 = inclmiss ? gradient[1].∂²𝑙 : 0.0
    bestloss = getloss(∂𝑙sum0 + miss∂𝑙, ∂²𝑙sum0 + miss∂²𝑙, λ, γ)
    levelcount = length(partition.mask)
    split = SplitNode(factor, partition, LevelPartition(zeros(Bool, levelcount), false),
                      LossGradient(∂𝑙sum0 + miss∂𝑙, ∂²𝑙sum0 + miss∂²𝑙), LossGradient(0.0f0, 0.0f0),
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

function getnewsplit(gradient::Vector{Vector{LossGradient}}, nodes::Vector{TreeNode}, factor::AbstractFactor,
                     λ::Float32, γ::Float32, min∂²𝑙::Float32, singlethread::Bool)
    newsplit = Vector{Nullable{SplitNode}}(length(gradient))
    if !singlethread
        Threads.@threads for i in 1:length(gradient)
            grad = gradient[i]
            if nodes[i].cansplit
                partition = nodes[i].partitions[factor]
                if count(partition.mask) > 1
                    newsplit[i] = getsplitnode(factor, nodes[i].partitions[factor],  grad, λ, γ, min∂²𝑙)
                else
                    newsplit[i] = Nullable{SplitNode}()
                end
            else
                newsplit[i] = Nullable{SplitNode}()
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
                    newsplit[i] = Nullable{SplitNode}()
                end
            else
                newsplit[i] = Nullable{SplitNode}()
            end         
        end
    end
    newsplit
end 

function findbestsplit(nodeids::Vector{<:Integer}, nodes::Vector{TreeNode}, factors::Vector{<:AbstractFactor},
                       ∂𝑙covariate::AbstractCovariate, ∂²𝑙covariate::AbstractCovariate,
                       λ::Float32, γ::Float32, min∂²𝑙::Float32, slicelength::Integer, singlethread::Bool)

    foldl(nodes, enumerate(factors)) do currsplit, nfactor
        n, factor = nfactor
        partitions = [node.partitions[factor] for node in nodes]
        nodecansplit = [n.cansplit for n in nodes]

        gradient = sumgradient(nodeids, nodecansplit, factor, partitions, ∂𝑙covariate, ∂²𝑙covariate, slicelength, singlethread)
        
        newsplit = getnewsplit(gradient, nodes, factor, λ, γ, min∂²𝑙, singlethread)

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

function updatestate(state::TreeGrowState, layer::TreeLayer, singlethread::Bool)
    splitnodeids!(state.nodeids, layer, state.slicelength, singlethread)  
    factors = state.factors
    newnodes = Vector{LeafNode}(2 * length(state.nodes))
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
                               state.γ, state.min∂²𝑙, state.slicelength, state.singlethread)
    layer = TreeLayer(layernodes)
    updatestate(state, layer, state.singlethread)
    Nullable{TreeLayer}(layer), state      
end

function predict(treelayer::TreeLayer, nodeids::Vector{<:Integer}, λ::Float32)
    weights = Vector{Float32}(2 * length(treelayer.nodes))
    @inbounds for (i, node) in enumerate(treelayer.nodes)
        if isa(node, SplitNode)
            weights[2 * i - 1] = getweight(node.leftgradient, λ)
            weights[2 * i] = getweight(node.rightgradient, λ)
        else
            weights[2 * i - 1] = getweight(node.gradient, λ)
            weights[2 * i] = getweight(node.gradient, λ)
        end
    end
    (nodeid -> nodeid > 0 ? weights[nodeid] : NaN32).(nodeids)
end

function predict(tree::Tree, dataframe::AbstractDataFrame)
    len = length(dataframe)
    maxnodecount = 2 ^ tree.maxdepth
    nodeids = maxnodecount <= typemax(UInt8) ? ones(UInt8, len) : (maxnodecount <= typemax(UInt16) ? ones(UInt16, len) : ones(UInt32, len))
    nodes = Vector{TreeNode}()
    for layer in tree.layers
        nodes = [isa(n, SplitNode) ? SplitNode(map(n.factor, dataframe), n.leftpartition, n.rightpartition, n.leftgradient, n.rightgradient, n.loss) : n for n in layer.nodes]
        splitnodeids!(nodeids, TreeLayer(nodes), tree.slicelength, tree.singlethread)
    end
    predict(TreeLayer(nodes), nodeids, tree.λ)
end

function growtree(factors::Vector{<:AbstractFactor}, ∂𝑙covariate::AbstractCovariate,
                  ∂²𝑙covariate::AbstractCovariate, maxdepth::Integer, λ::Float32, γ::Float32,
                  min∂²𝑙::Float32, slicelength::Integer, singlethread::Bool)

    len = length(∂𝑙covariate)
    maxnodecount = 2 ^ maxdepth
    nodeids = maxnodecount <= typemax(UInt8) ? ones(UInt8, len) : (maxnodecount <= typemax(UInt16) ? ones(UInt16, len) : ones(UInt32, len))
    intercept = ConstFactor(len)
    grad0 = sumgradient(nodeids, [true], intercept, [LevelPartition([true], false)], ∂𝑙covariate, ∂²𝑙covariate, slicelength, singlethread)[1][1]
    nodes0 = Vector{TreeNode}()
    push!(nodes0, LeafNode(grad0, true, Dict([f => LevelPartition(ones(Bool, length(getlevels(f))), true) for f in factors])))
    state0 = TreeGrowState(nodeids, nodes0, factors, ∂𝑙covariate, ∂²𝑙covariate, λ, γ, min∂²𝑙, slicelength, singlethread)
    layers = collect(Iterators.take(Seq(TreeLayer, state0, nextlayer), maxdepth))
    tree = Tree(layers, λ, γ, min∂²𝑙, maxdepth, slicelength, singlethread)
    pred = predict(tree.layers[end], nodeids, λ)
    tree, pred
end

