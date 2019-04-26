mutable struct LossGradient{T<:AbstractFloat}
    ∂𝑙::T
    ∂²𝑙::T
end

function Base.:+(x::LossGradient{T}, y::LossGradient{T}) where {T<:AbstractFloat}
    LossGradient{T}(x.∂𝑙 + y.∂𝑙, x.∂²𝑙 + y.∂²𝑙)
end

mutable struct LevelPartition
    mask::Vector{Bool}
    inclmissing::Bool
end

abstract type TreeNode{T<:AbstractFloat} end

mutable struct LeafNode{T<:AbstractFloat} <: TreeNode{T}
    gradient::LossGradient{T}
    cansplit::Bool
    partitions::Dict{AbstractFactor, LevelPartition}
end

mutable struct SplitNode{T<:AbstractFloat} <: TreeNode{T}
    factor::AbstractFactor
    leftnode::LeafNode{T}
    rightnode::LeafNode{T}
    loss::T
    isactive::Bool
    gain::T
end

struct TreeLayer{T<:AbstractFloat}
    nodes::Vector{<:TreeNode{T}}
end

struct XGTree{T<:AbstractFloat}
    layers::Vector{TreeLayer{T}}
    λ::T
    γ::T
    min∂²𝑙::T
    maxdepth::Integer
    leafwise::Bool
    maxleaves::Integer
    slicelength::Integer
    singlethread::Bool
end

mutable struct TreeGrowState{T<:AbstractFloat}
    nodeids::Vector{<:Integer}
    nodes::Vector{TreeNode{T}}
    factors::Vector{<:AbstractFactor}
    ∂𝑙covariate::AbstractCovariate
    ∂²𝑙covariate::AbstractCovariate
    λ::T
    γ::T
    min∂²𝑙::T
    ordstumps::Bool
    optsplit::Bool
    pruning::Bool
    leafwise::Bool
    slicelength::Integer
    singlethread::Bool
end

struct XGModel{T<:AbstractFloat}
    trees::Vector{XGTree{T}}
    λ::T
    γ::T
    η::T
    minchildweight::T
    maxdepth::Integer
    pred::Vector{T}
end
