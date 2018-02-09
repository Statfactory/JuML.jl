mutable struct LossGradient{T<:AbstractFloat}
    ∂𝑙::T
    ∂²𝑙::T
end

mutable struct LevelPartition
    mask::Vector{Bool}
    inclmissing::Bool
end

abstract type TreeNode end

mutable struct LeafNode <: TreeNode
    gradient::LossGradient
    cansplit::Bool
    partitions::Dict{AbstractFactor, LevelPartition}
end

mutable struct SplitNode{T<:AbstractFloat} <: TreeNode
    factor::AbstractFactor
    leftpartition::LevelPartition
    rightpartition::LevelPartition
    leftgradient::LossGradient{T}
    rightgradient::LossGradient{T}
    loss::T
end

struct TreeLayer
    nodes::Vector{<:TreeNode}
end

struct Tree{T<:AbstractFloat}
    layers::Vector{TreeLayer}
    λ::T
    γ::T
    min∂²𝑙::T
    maxdepth::Integer
    slicelength::Integer
    singlethread::Bool
end

mutable struct TreeGrowState{T<:AbstractFloat}
    nodeids::Vector{<:Integer}
    nodes::Vector{TreeNode}
    factors::Vector{<:AbstractFactor}
    ∂𝑙covariate::AbstractCovariate
    ∂²𝑙covariate::AbstractCovariate
    λ::T
    γ::T
    min∂²𝑙::T
    slicelength::Integer
    singlethread::Bool
end

struct XGModel{T<:AbstractFloat}
    trees::Vector{Tree}
    λ::T
    γ::T
    η::T
    minchildweight::T
    maxdepth::Integer
    pred::Vector{T}
end
