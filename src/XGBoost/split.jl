
function getweight(gradient::LossGradient{T}, λ::T) where {T<:AbstractFloat} 
    -gradient.∂𝑙 / (gradient.∂²𝑙 + λ)
end

function getloss(∂𝑙::T, ∂²𝑙::T, λ::T) where {T<:AbstractFloat} 
    a::T = -0.5
    a * ∂𝑙 * ∂𝑙 / (∂²𝑙 + λ)
end

function getloss(node::LeafNode{T}, λ::T) where {T<:AbstractFloat} 
    ∂𝑙 = node.gradient.∂𝑙
    ∂²𝑙 = node.gradient.∂²𝑙
    getloss(∂𝑙, ∂²𝑙, λ)
end

function getloss(node::SplitNode{T}, λ::T) where {T<:AbstractFloat} 
    node.loss
end

function getgain(node::LeafNode{T}) where {T<:AbstractFloat}
    zero(T)
end

function getgain(node::SplitNode{T}) where {T<:AbstractFloat}
    node.gain
end

function sumgradientslice!(∂𝑙sum0, ∂²𝑙sum0, nodeids::Vector{<:Integer}, nodecansplit::Vector{Bool}, factor::AbstractFactor,
                           ∂𝑙covariate::AbstractCovariate{T}, ∂²𝑙covariate::AbstractCovariate{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:AbstractFloat}

    nodeslices = slice(nodeids, fromobs, toobs, slicelength)
    factorslices = slice(factor, fromobs, toobs, slicelength)
    ∂𝑙slices = slice(∂𝑙covariate, fromobs, toobs, slicelength)
    ∂²𝑙slices = slice(∂²𝑙covariate, fromobs, toobs, slicelength)
    zipslices = zip(nodeslices, factorslices, ∂𝑙slices, ∂²𝑙slices)
    fold((∂𝑙sum0, ∂²𝑙sum0), zipslices) do gradsum, zipslice
        nodeslice, factorslice, ∂𝑙slice, ∂²𝑙slice = zipslice
        ∂𝑙sum, ∂²𝑙sum = gradsum
        @inbounds for i in 1:length(nodeslice)
            nodeid = nodeslice[i]
            if nodecansplit[nodeid]
                levelindex = factorslice[i] + 1
                ∂𝑙sum[nodeid][levelindex] += ∂𝑙slice[i]
                ∂²𝑙sum[nodeid][levelindex] += ∂²𝑙slice[i]
            end
        end
        (∂𝑙sum, ∂²𝑙sum)
    end
end

function sumgradient(nodeids::Vector{<:Integer}, nodecansplit::Vector{Bool}, factor::AbstractFactor, partitions::Vector{LevelPartition},
                     ∂𝑙covariate::AbstractCovariate{T}, ∂²𝑙covariate::AbstractCovariate{T}, slicelength::Integer, singlethread::Bool) where {T<:AbstractFloat}
    
    nodecount = length(nodecansplit)
    levelcounts = [length(p.mask) + 1 for p in partitions]
    fromobs = 1
    toobs = length(nodeids)

    nthreads = singlethread ? 1 : Threads.nthreads()
    threadspace = map((x -> Int64(floor(x))), range(fromobs, toobs, length = nthreads + 1))
    ∂𝑙sum = [[(nodecansplit[node] ? [zero(T) for i in 1:(levelcounts[node])] : Vector{T}()) for node in 1:nodecount] for i in 1:nthreads]
    ∂²𝑙sum = [[(nodecansplit[node] ? [zero(T) for i in 1:(levelcounts[node])] : Vector{T}()) for node in 1:nodecount] for i in 1:nthreads]

    if nthreads > 1
        Threads.@threads for i in 1:nthreads
            sumgradientslice!(∂𝑙sum[i], ∂²𝑙sum[i], nodeids, nodecansplit, factor,
                            ∂𝑙covariate, ∂²𝑙covariate, (i == 1 ? threadspace[i] : threadspace[i] + 1),
                            threadspace[i + 1], slicelength)
        end
        ∂𝑙sum = reduce(+, ∂𝑙sum)
        ∂²𝑙sum = reduce(+, ∂²𝑙sum)
        [(nodecansplit[node] ? [LossGradient{T}(∂𝑙sum[node][i], ∂²𝑙sum[node][i]) for i in 1:(levelcounts[node])] : Vector{LossGradient{T}}()) for node in 1:nodecount]
    else
        sumgradientslice!(∂𝑙sum[1], ∂²𝑙sum[1], nodeids, nodecansplit, factor,
                          ∂𝑙covariate, ∂²𝑙covariate, fromobs, toobs, slicelength)
        [(nodecansplit[node] ? [LossGradient{T}(∂𝑙sum[1][node][i], ∂²𝑙sum[1][node][i]) for i in 1:(levelcounts[node])] : Vector{LossGradient{T}}()) for node in 1:nodecount]
    end
end

function splitnodeidsslice!(nodeids::Vector{<:Integer}, factors, issplitnode::Vector{Bool}, nodemap::Vector{Int64},
                            leftpartitions::Vector{Vector{Bool}}, factorindex::Vector{Int64},
                            fromobs::Integer, toobs::Integer, slicelength::Integer)
    if length(factors) > 0
        factorslices = zip(Tuple([slice(factor, fromobs, toobs, slicelength) for factor in factors]))
        nodeslices = slice(nodeids, fromobs, toobs, slicelength)
        foreach(zip(nodeslices, factorslices)) do x
            nodeslice, fslices = x
            @inbounds for i in 1:length(nodeslice)
                nodeid = nodeslice[i]
                if issplitnode[nodeid]
                    levelindex = fslices[factorindex[nodeid]][i]
                    nodeslice[i] = (leftpartitions[nodeid][levelindex + 1]) ? nodemap[nodeslice[i]] : nodemap[nodeslice[i]] + 1
                else
                    nodeslice[i] = nodemap[nodeslice[i]]
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
    issplitnode = [isa(n, SplitNode) && n.isactive for n in nodes]
    nodemap = Vector{Int64}()
    splitnodecount = 0
    for (i, x) in enumerate(issplitnode)
        push!(nodemap, i + splitnodecount) 
        if x
            splitnodecount += 1
        end
    end
    factors = Vector{AbstractFactor}()
    factorindex = zeros(Int64, nodecount)
    for i in 1:nodecount
         if issplitnode[i]
             factor = nodes[i].factor
             index = findfirst((x -> x == factor), factors)
             if index === nothing
                 push!(factors, factor)
             end
             factorindex[i] = findfirst((x -> x == factor), factors)
         end
    end
    leftpartitions = [isa(n, SplitNode) && n.isactive ? [n.leftnode.partitions[n.factor].inclmissing; n.leftnode.partitions[n.factor].mask] : Vector{Bool}() for n in nodes]

    nthreads = singlethread ? 1 : Threads.nthreads()
    if nthreads > 1
        threadspace = map((x -> Int64(floor(x))), range(fromobs, toobs, length = nthreads + 1))
        Threads.@threads for j in 1:nthreads
             splitnodeidsslice!(nodeids, factors, issplitnode, nodemap, leftpartitions, factorindex,
                                j == 1 ? threadspace[j] : threadspace[j] + 1,
                                threadspace[j + 1], slicelength)
        end
    else
        splitnodeidsslice!(nodeids, factors, issplitnode, nodemap, leftpartitions, factorindex,
                           fromobs, toobs, slicelength)
    end
    nodeids
end

function getsplitnode(factor::AbstractFactor, leafnode::LeafNode{T}, gradient::Vector{LossGradient{T}},
                      λ::T, min∂²𝑙::T, ordstumps::Bool, optsplit::Bool) where {T<:AbstractFloat}

    partition = leafnode.partitions[factor]
    isord = isordinal(factor)
    gradstart = findfirst(partition.mask) + 1
    ∂𝑙sum0 = sum((grad -> grad.∂𝑙), gradient[gradstart:end])
    ∂²𝑙sum0 = sum((grad -> grad.∂²𝑙), gradient[gradstart:end]) 
    k = length(gradient) - gradstart + 1
    f = isord ? collect(1:k) : 
        (optsplit ? sortperm([gradient[i].∂𝑙 / gradient[i].∂²𝑙 for i in gradstart:length(gradient)]) : collect(1:k))
    miss∂𝑙 = gradient[1].∂𝑙 
    miss∂²𝑙 = gradient[1].∂²𝑙
    currloss = getloss(∂𝑙sum0 + miss∂𝑙, ∂²𝑙sum0 + miss∂²𝑙, λ)
    bestloss = typemax(T) 
    levelcount = length(partition.mask)
    leftnode = LeafNode{T}(LossGradient{T}(∂𝑙sum0 + miss∂𝑙, ∂²𝑙sum0 + miss∂²𝑙), true, copy(leafnode.partitions))
    rightnode = LeafNode{T}(LossGradient{T}(zero(T), zero(T)), true, copy(leafnode.partitions))
    split = SplitNode{T}(factor, leftnode, rightnode, bestloss, false, zero(T))
    leftpartition = deepcopy(leftnode.partitions[factor])
    rightpartition = deepcopy(rightnode.partitions[factor])
    
    left∂𝑙sum = isord ? gradient[gradstart].∂𝑙 : gradient[gradstart + f[1] - 1].∂𝑙
    left∂²𝑙sum = isord ? gradient[gradstart].∂²𝑙 : gradient[gradstart + f[1] - 1].∂²𝑙

    firstlevelwithmiss = getloss(left∂𝑙sum + miss∂𝑙, left∂²𝑙sum + miss∂²𝑙, λ) + getloss(∂𝑙sum0 - left∂𝑙sum, ∂²𝑙sum0 - left∂²𝑙sum, λ)
    firstlevelwitouthmiss = getloss(left∂𝑙sum, left∂²𝑙sum, λ) + getloss(∂𝑙sum0 - left∂𝑙sum + miss∂𝑙, ∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙, λ)

    if firstlevelwithmiss < bestloss && (left∂²𝑙sum + miss∂²𝑙 >= min∂²𝑙) && (∂²𝑙sum0 - left∂²𝑙sum >= min∂²𝑙)
        if firstlevelwitouthmiss < firstlevelwithmiss && (left∂²𝑙sum >= min∂²𝑙) && (∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙 >= min∂²𝑙)
            split.leftnode.gradient.∂𝑙 = left∂𝑙sum
            split.leftnode.gradient.∂²𝑙 = left∂²𝑙sum
            split.rightnode.gradient.∂𝑙 = ∂𝑙sum0 - left∂𝑙sum + miss∂𝑙
            split.rightnode.gradient.∂²𝑙 = ∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙
            for j in (gradstart - 1):levelcount
                leftpartition.mask[j] = j == (gradstart + f[1] - 2)
                rightpartition.mask[j] = j == (gradstart + f[1] - 2) ? false : partition.mask[j]
            end
            leftpartition.inclmissing = false
            rightpartition.inclmissing = partition.inclmissing
            split.loss = firstlevelwitouthmiss
        else
            split.leftnode.gradient.∂𝑙 = left∂𝑙sum + miss∂𝑙
            split.leftnode.gradient.∂²𝑙 = left∂²𝑙sum + miss∂²𝑙
            split.rightnode.gradient.∂𝑙 = ∂𝑙sum0 - left∂𝑙sum
            split.rightnode.gradient.∂²𝑙 = ∂²𝑙sum0 - left∂²𝑙sum
            for j in (gradstart - 1):levelcount
                leftpartition.mask[j] = j == (gradstart + f[1] - 2)
                rightpartition.mask[j] = j == (gradstart + f[1] - 2) ? false : partition.mask[j]
            end
            leftpartition.inclmissing = partition.inclmissing
            rightpartition.inclmissing = false
            split.loss = firstlevelwithmiss
        end
    end

    @inbounds for i in (gradstart + 1):(levelcount + 1)
        fi = isord ? i : (gradstart - 1) + f[(i - gradstart) + 1]
        if !partition.mask[fi - 1]
            continue
        end
        ∂𝑙 = gradient[fi].∂𝑙
        ∂²𝑙 = gradient[fi].∂²𝑙

        singlelevelwithmisstotal = getloss(∂𝑙 + miss∂𝑙, ∂²𝑙 + miss∂²𝑙, λ) + getloss(∂𝑙sum0 - ∂𝑙, ∂²𝑙sum0 - ∂²𝑙, λ)
        singlelevelwitouthmisstotal = getloss(∂𝑙, ∂²𝑙, λ) + getloss(∂𝑙sum0 - ∂𝑙 + miss∂𝑙, ∂²𝑙sum0 - ∂²𝑙 + miss∂²𝑙, λ)

        left∂𝑙sum += ∂𝑙
        left∂²𝑙sum += ∂²𝑙

        leftwithmisstotal = getloss(left∂𝑙sum + miss∂𝑙, left∂²𝑙sum + miss∂²𝑙, λ) + getloss(∂𝑙sum0 - left∂𝑙sum, ∂²𝑙sum0 - left∂²𝑙sum, λ)
        leftwithoutmisstotal = getloss(left∂𝑙sum, left∂²𝑙sum, λ) + getloss(∂𝑙sum0 - left∂𝑙sum + miss∂𝑙, ∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙, λ)

        if !isord
            if singlelevelwithmisstotal < split.loss && (∂²𝑙 + miss∂²𝑙 >= min∂²𝑙) && (∂²𝑙sum0 - ∂²𝑙 >= min∂²𝑙)
                if singlelevelwitouthmisstotal < singlelevelwithmisstotal && (∂²𝑙 >= min∂²𝑙) && (∂²𝑙sum0 - ∂²𝑙 + miss∂²𝑙 >= min∂²𝑙)
                    split.leftnode.gradient.∂𝑙 = ∂𝑙
                    split.leftnode.gradient.∂²𝑙 =  ∂²𝑙
                    split.rightnode.gradient.∂𝑙 = ∂𝑙sum0 - ∂𝑙 + miss∂𝑙
                    split.rightnode.gradient.∂²𝑙 = ∂²𝑙sum0 - ∂²𝑙 + miss∂²𝑙
                    leftpartition.inclmissing = false
                    rightpartition.inclmissing = partition.inclmissing
                    split.loss = singlelevelwitouthmisstotal
                else
                    split.leftnode.gradient.∂𝑙 = ∂𝑙 + miss∂𝑙
                    split.leftnode.gradient.∂²𝑙 =  ∂²𝑙 + miss∂²𝑙
                    split.rightnode.gradient.∂𝑙 = ∂𝑙sum0 - ∂𝑙
                    split.rightnode.gradient.∂²𝑙 = ∂²𝑙sum0 - ∂²𝑙
                    leftpartition.inclmissing = partition.inclmissing
                    rightpartition.inclmissing = false
                    split.loss = singlelevelwithmisstotal
                end
                fi = isord ? (i - 1) : (fi - 1)
                for j in (gradstart - 1):levelcount
                    leftpartition.mask[j] = j == fi
                    rightpartition.mask[j] = j == fi ? false : partition.mask[j]
                end
            end
        end
        
        if isord
            if leftwithmisstotal < split.loss && (left∂²𝑙sum + miss∂²𝑙 >= min∂²𝑙) && (∂²𝑙sum0 - left∂²𝑙sum >= min∂²𝑙)
                if leftwithoutmisstotal < leftwithmisstotal && (left∂²𝑙sum >= min∂²𝑙) && (∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙 >= min∂²𝑙)
                    split.leftnode.gradient.∂𝑙 = left∂𝑙sum
                    split.leftnode.gradient.∂²𝑙 = left∂²𝑙sum
                    split.rightnode.gradient.∂𝑙 = ∂𝑙sum0 - left∂𝑙sum + miss∂𝑙
                    split.rightnode.gradient.∂²𝑙 = ∂²𝑙sum0 - left∂²𝑙sum + miss∂²𝑙
                    leftpartition.inclmissing = false
                    rightpartition.inclmissing = partition.inclmissing
                    split.loss = leftwithoutmisstotal
                else
                    split.leftnode.gradient.∂𝑙 = left∂𝑙sum + miss∂𝑙
                    split.leftnode.gradient.∂²𝑙 = left∂²𝑙sum + miss∂²𝑙
                    split.rightnode.gradient.∂𝑙 = ∂𝑙sum0 - left∂𝑙sum
                    split.rightnode.gradient.∂²𝑙 = ∂²𝑙sum0 - left∂²𝑙sum
                    leftpartition.inclmissing = partition.inclmissing
                    rightpartition.inclmissing = false
                    split.loss = leftwithmisstotal
                end
                for j in (gradstart - 1):levelcount
                    fj = isord ? j : (gradstart - 2) + f[(j - gradstart) + 2]
                    if j <= i - 1
                        leftpartition.mask[fj] = partition.mask[fj]
                        rightpartition.mask[fj] = false
                    else
                        leftpartition.mask[fj] = false
                        rightpartition.mask[fj] = partition.mask[fj]
                    end
                end
            end
        end
    end

    if count(rightpartition.mask) > 0 && split.loss < typemax(T)
        split.gain = currloss - split.loss
        leftnode.partitions[factor] = leftpartition
        leftnode.cansplit = leftnode.gradient.∂²𝑙 >= min∂²𝑙
        rightnode.partitions[factor] = rightpartition
        rightnode.cansplit = rightnode.gradient.∂²𝑙 >= min∂²𝑙
        split
    else
        nothing
    end
end

function getnewsplit(gradient::Vector{Vector{LossGradient{T}}}, nodes::Vector{TreeNode{T}}, factor::AbstractFactor,
                     λ::T, γ::T, min∂²𝑙::T, ordstumps::Bool, optsplit::Bool, singlethread::Bool) where {T<:AbstractFloat}
    newsplit = Vector{Union{SplitNode{T}, Nothing}}(undef, length(gradient))
    if !singlethread && length(gradient) > 2 * Threads.nthreads()
        Threads.@threads for i in 1:length(gradient)
            grad = gradient[i]
            if isa(nodes[i], LeafNode) && nodes[i].cansplit
                partition = nodes[i].partitions[factor]
                if count(partition.mask) > 1
                    newsplit[i] = getsplitnode(factor, nodes[i],  grad, λ, min∂²𝑙, ordstumps, optsplit)
                else
                    newsplit[i] = nothing
                end
            else
                newsplit[i] = nothing
            end         
        end
    else
        for i in 1:length(gradient)
            grad = gradient[i]
            if isa(nodes[i], LeafNode) && nodes[i].cansplit
                partition = nodes[i].partitions[factor]
                if count(partition.mask) > 1
                    newsplit[i] = getsplitnode(factor, nodes[i],  grad, λ, min∂²𝑙, ordstumps, optsplit)
                else
                    newsplit[i] = nothing
                end
            else
                newsplit[i] = nothing
            end         
        end
    end
    newsplit
end 

function findbestsplit(state::TreeGrowState{T}) where {T<:AbstractFloat}

    nodecansplit = [isa(n, LeafNode) && n.cansplit for n in state.nodes]
    mingain = T(0.5) * state.γ
    currloss = [getloss(n, state.λ) for n in state.nodes]
    res = foldl(enumerate(state.factors); init = state.nodes) do currsplit, nfactor
        n, factor = nfactor
        partitions = [isa(node, LeafNode) && node.cansplit ? node.partitions[factor] : LevelPartition(Vector{Bool}(), false) for node in state.nodes]

        gradient = sumgradient(state.nodeids, nodecansplit, factor, partitions, state.∂𝑙covariate, state.∂²𝑙covariate, state.slicelength, state.singlethread)
        
        newsplit = getnewsplit(gradient, state.nodes, factor, state.λ, state.γ, state.min∂²𝑙, state.ordstumps, state.optsplit, state.singlethread)

        res = Vector{TreeNode{T}}(undef, length(newsplit))
        @inbounds for i in 1:length(newsplit)
            if newsplit[i] !== nothing
               newloss = newsplit[i].loss
               newgain = newsplit[i].gain
               if newgain > mingain && newloss < getloss(currsplit[i], state.λ)
                   res[i] = newsplit[i]
               else
                   res[i] = currsplit[i] 
               end
            else
               res[i] = currsplit[i] 
            end
        end
        res

        # if state.leafwise
        #     gain = map(getgain, res)
        #     (maxgain, imax) = findmax(gain)
        #     if maxgain > mingain

        #     end

        #     gain = [isnull(newsplit[i]) ? T(NaN32) : currloss[i] - get(newsplit[i]).loss for i in 1:length(newsplit)]
        #     (maxgain, imax) = findmax(gain)
        #     if maxgain > bestgain
        #         bestgain = maxgain
        #         @inbounds for i in 1:length(newsplit)
        #             if i == imax
        #                 res[i] = get(newsplit[i])
        #             else
        #                 res[i] = state.nodes[i] 
        #             end
        #         end
        #     else
        #         @inbounds for i in 1:length(newsplit)
        #                 res[i] = currsplit[i] 
        #         end
        #     end
        # else
        #     mingain = T(0.5) * state.γ
        #     @inbounds for i in 1:length(newsplit)
        #         if !isnull(newsplit[i])
        #            newloss = get(newsplit[i]).loss
        #            if currloss[i] - newloss > mingain && newloss < getloss(currsplit[i], state.λ)
        #                res[i] = get(newsplit[i])
        #            else
        #                res[i] = currsplit[i] 
        #            end
        #         else
        #            res[i] = currsplit[i] 
        #         end
        #    end
        #end
    end
    if state.leafwise
        gain = map(getgain, res)
        (maxgain, imax) = findmax(gain)
        if maxgain > mingain
            @inbounds for i in 1:length(res)
                if i == imax && isa(res[i], SplitNode)
                    res[i].isactive = true
                elseif isa(res[i], SplitNode)
                    res[i].isactive = false
                end
            end
        end
    else
        @inbounds for i in 1:length(res)
            if isa(res[i], SplitNode)
                res[i].isactive = true
            end
        end
    end
    res
end

function updatestate(state::TreeGrowState{T}, layer::TreeLayer{T}) where {T<:AbstractFloat}
    splitnodeids!(state.nodeids, layer, state.slicelength, state.singlethread)  
    factors = state.factors
    newnodes = Vector{TreeNode{T}}()
    @inbounds for (i, n) in enumerate(layer.nodes)
        if isa(n, SplitNode) && n.isactive
            push!(newnodes, n.leftnode)
            push!(newnodes, n.rightnode)
            # if isa(state.nodes[i], LeafNode)
            #     leftpartitions = map(state.nodes[i].partitions) do x
            #         f, p = x
            #         if f == n.factor
            #             f => n.leftpartition
            #         else
            #             x
            #         end
            #     end
            #     rightpartitions = map(state.nodes[i].partitions) do x
            #         f, p = x
            #         if f == n.factor
            #             f => n.rightpartition
            #         else
            #             x
            #         end
            #     end
            #     push!(newnodes, LeafNode{T}(n.leftgradient,
            #                                 n.leftgradient.∂²𝑙 >= state.min∂²𝑙,
            #                                 leftpartitions))
            #     push!(newnodes, LeafNode{T}(n.rightgradient,
            #                                 n.rightgradient.∂²𝑙 >= state.min∂²𝑙,
            #                                 rightpartitions))
        else
            push!(newnodes, n)
        end
    end
    # activefactors = filter(factors) do f
    #     any(map((n -> count(n.partitions[f].mask) > 1), newnodes))
    # end 
    # state.factors = activefactors
    # for n in newnodes
    #     n.partitions = filter(n.partitions) do f, p
    #         f in activefactors
    #     end
    # end
    state.nodes = newnodes
    state
end

function nextlayer(state::TreeGrowState{T}) where {T<:AbstractFloat}
    layernodes = findbestsplit(state)
    layer = TreeLayer{T}(layernodes)
    updatestate(state, layer)
    layer, state      
end

function predict(treelayer::TreeLayer{T}, nodeids::Vector{<:Integer}, λ::T) where {T<:AbstractFloat}
    weights = Vector{T}()
    @inbounds for (i, node) in enumerate(treelayer.nodes)
        if isa(node, SplitNode) && node.isactive
            push!(weights, getweight(node.leftnode.gradient, λ))
            push!(weights, getweight(node.rightnode.gradient, λ))
        elseif isa(node, SplitNode) 
            push!(weights, getweight(node.leftnode.gradient + node.rightnode.gradient, λ))
        else
            push!(weights, getweight(node.gradient, λ))
        end
    end
    (nodeid -> nodeid > 0 ? weights[nodeid] : T(NaN32)).(nodeids)
end

function getlevelmap(fromfactor::AbstractFactor, tofactor::AbstractFactor)
    fromlevels = getlevels(fromfactor)
    tolevels = getlevels(tofactor)
    levelmap = Dict{Int64, Int64}()
    for (i, level) in enumerate(fromlevels)
        j = findfirst((x -> x == level), tolevels)
        if j !== nothing
            levelmap[i] = j
        end
    end
    levelmap
end

function getnewindices(fromfactor::AbstractFactor, tofactor::AbstractFactor)
    fromlevels = getlevels(fromfactor)
    tolevels = getlevels(tofactor)
    newind = Set{Int64}()
    for (i, level) in enumerate(tolevels)
        j = findfirst((x -> x == level), fromlevels)
        if j !== nothing
            push!(newind, i)
        end
    end
    newind
end

function Base.map(node::SplitNode{T}, dataframe::AbstractDataFrame, 
                  factormap::Dict{AbstractFactor, Tuple{AbstractFactor, Dict{Int64, Int64}, Set{Int64}, Int64}}) where {T<:AbstractFloat}
    
    factor, levelmap, newind, levelcount = factormap[node.factor]
    leftmask = Vector{Bool}(undef, levelcount)
    rightmask = Vector{Bool}(undef, levelcount)
    for (i, j) in levelmap
        leftmask[j] = node.leftnode.partitions[node.factor].mask[i] 
        rightmask[j] = node.rightnode.partitions[node.factor].mask[i] 
    end
    for i in newind
        leftmask[i] = false
        rightmask[i] = true
    end
    node.leftnode.partitions[factor] = LevelPartition(leftmask, node.leftnode.partitions[node.factor].inclmissing)
    node.rightnode.partitions[factor] = LevelPartition(rightmask, node.rightnode.partitions[node.factor].inclmissing)
    SplitNode{T}(factor, node.leftnode, node.rightnode, node.loss, node.isactive, node.gain)
end

function Base.map(node::LeafNode{T}, dataframe::AbstractDataFrame,
                  factormap::Dict{AbstractFactor, Tuple{AbstractFactor, Dict{Int64, Int64}, Set{Int64}, Int64}}) where {T<:AbstractFloat}
    node
end

function predict(tree::XGTree{T}, dataframe::AbstractDataFrame) where {T<:AbstractFloat}
    len = length(dataframe)
    maxnodecount = tree.leafwise ? tree.maxleaves : 2 ^ tree.maxdepth
    nodeids = maxnodecount <= typemax(UInt8) ? ones(UInt8, len) : (maxnodecount <= typemax(UInt16) ? ones(UInt16, len) : ones(UInt32, len))
    for layer in tree.layers
        splitnodeids!(nodeids, layer, tree.slicelength, tree.singlethread)
    end
    predict(tree.layers[end], nodeids, tree.λ)
end

function growtree(factors::Vector{<:AbstractFactor}, ∂𝑙covariate::AbstractCovariate{T},
                  ∂²𝑙covariate::AbstractCovariate{T}, maxdepth::Integer, λ::T, γ::T, leafwise::Bool, maxleaves::Integer,
                  min∂²𝑙::T, ordstumps::Bool, optsplit::Bool, pruning::Bool, slicelength::Integer, singlethread::Bool) where {T<:AbstractFloat}

    len = length(∂𝑙covariate)
    maxnodecount = leafwise ? maxleaves : 2 ^ maxdepth
    maxsteps = leafwise ? (maxleaves - 1) : maxdepth
    nodeids = maxnodecount <= typemax(UInt8) ? ones(UInt8, len) : (maxnodecount <= typemax(UInt16) ? ones(UInt16, len) : ones(UInt32, len))
    intercept = ConstFactor(len)
    @time grad0 = sumgradient(nodeids, [true], intercept, [LevelPartition([true], false)], ∂𝑙covariate, ∂²𝑙covariate, slicelength, singlethread)[1][1]
    nodes0 = Vector{TreeNode{T}}()
    push!(nodes0, LeafNode{T}(grad0, true, Dict([f => LevelPartition(ones(Bool, length(getlevels(f))), true) for f in factors])))
    state0 = TreeGrowState{T}(nodeids, nodes0, factors, ∂𝑙covariate, ∂²𝑙covariate, λ, γ, min∂²𝑙, ordstumps, optsplit, pruning, leafwise, slicelength, singlethread)
    @time layers = collect(Iterators.take(Seq(TreeLayer{T}, state0, nextlayer), maxsteps))
    xgtree = XGTree{T}(layers, λ, γ, min∂²𝑙, maxdepth, leafwise, maxleaves, slicelength, singlethread)
    if pruning
        tree = convert(Tree{TreeNode{T}}, xgtree)
        pruned = prune(tree, λ, γ)
        prunedlayers = map((nodes -> TreeLayer{T}(nodes)) , convert(Vector{Vector{TreeNode{T}}}, convert(List{List{TreeNode{T}}}, rebalance(pruned, maxdepth))))
        xgtree = XGTree{T}(prunedlayers, λ, γ, min∂²𝑙, maxdepth, leafwise, maxleaves, slicelength, singlethread)
        pred = predict(xgtree.layers[end], nodeids, λ)
        xgtree, pred
    else
        pred = predict(xgtree.layers[end], nodeids, λ)
        xgtree, pred
    end
end

function Base.convert(::Type{Tree{TreeNode{T}}}, xgtree::XGTree{T}) where {T<:AbstractFloat} 
    layers = xgtree.layers
    maxdepth = xgtree.maxdepth
    gettree  = (depth::Integer, nodeid::Integer) -> 
        begin
            node = layers[depth].nodes[nodeid]
            if depth == maxdepth
                ConsTree{TreeNode{T}}(node)
            else
                lefttree = gettree(depth + 1, 2 * nodeid - 1)
                righttree = gettree(depth + 1, 2 * nodeid)
                ConsTree{TreeNode{T}}(node, lefttree, righttree)
            end
        end
    gettree(1, 1)
end

function Base.convert(::Type{List{List{TreeNode{T}}}}, tree::EmptyTree{TreeNode{T}}) where {T<:AbstractFloat}
    EmptyList{EmptyList{TreeNode{T}}}()
end

function Base.convert(::Type{List{List{TreeNode{T}}}}, tree::ConsTree{TreeNode{T}}) where {T<:AbstractFloat}
    node = tree.value
    left = convert(List{List{TreeNode{T}}}, tree.lefttree)
    right = convert(List{List{TreeNode{T}}}, tree.righttree)
    ConsList{List{TreeNode{T}}}(ConsList{TreeNode{T}}(node), map((x -> x[1] + x[2]), zip(left, right), List{TreeNode{T}}))
end

function prune(node::SplitNode{T}, λ::T, γ::T) where {T<:AbstractFloat}
    sumgrad = LossGradient(node.leftgradient.∂𝑙 + node.rightgradient.∂𝑙, node.leftgradient.∂²𝑙 + node.rightgradient.∂²𝑙)
    totloss = getloss(sumgrad.∂𝑙, sumgrad.∂²𝑙, λ)
    if totloss - node.loss > γ * T(0.5)
        node::TreeNode{T}
    else
        LeafNode(sumgrad, false, Dict{AbstractFactor, LevelPartition}())::TreeNode{T}
    end
end

function prune(node::LeafNode{T}, λ::T, γ::T) where {T<:AbstractFloat}
    node
end

function prune(tree::ConsTree{<:TreeNode{T}}, λ::T, γ::T) where {T<:AbstractFloat}
    node = tree.value
    if isempty(tree.lefttree) && isempty(tree.righttree)
        ConsTree{TreeNode{T}}(prune(node, λ, γ))
    else
        prunednode = prune(node, λ, γ)
        if isa(prunednode, LeafNode{T})
            ConsTree{TreeNode{T}}(prunednode)
        else
            left = prune(tree.lefttree, λ, γ)
            right = prune(tree.righttree, λ, γ)
            ConsTree{TreeNode{T}}(prunednode, left, right)
        end
    end
end

function rebalance(prunedtree::ConsTree{TreeNode{T}}, maxdepth::Integer) where {T<:AbstractFloat}
    if maxdepth == 1
        prunedtree
    else
        if isempty(prunedtree.lefttree) && isempty(prunedtree.righttree) 
            left = rebalance(ConsTree{TreeNode{T}}(prunedtree.value), maxdepth - 1)
            right = rebalance(ConsTree{TreeNode{T}}(prunedtree.value), maxdepth - 1)
            ConsTree{TreeNode{T}}(prunedtree.value, left, right)
        else
            left = rebalance(prunedtree.lefttree, maxdepth - 1)
            right = rebalance(prunedtree.righttree, maxdepth - 1)
            ConsTree{TreeNode{T}}(prunedtree.value, left, right)
        end
    end
end

