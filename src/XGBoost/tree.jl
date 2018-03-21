mutable struct LossGradient{T<:AbstractFloat}
    ∂𝑙::T
    ∂²𝑙::T
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
    leftpartition::LevelPartition
    rightpartition::LevelPartition
    leftgradient::LossGradient{T}
    rightgradient::LossGradient{T}
    loss::T
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
