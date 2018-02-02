mutable struct LossGradient
    ∂𝑙::Float64
    ∂²𝑙::Float64
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

mutable struct SplitNode <: TreeNode
    factor::AbstractFactor
    leftpartition::LevelPartition
    rightpartition::LevelPartition
    leftgradient::LossGradient
    rightgradient::LossGradient
    loss::Real
end

struct TreeLayer
    nodes::Vector{<:TreeNode}
end

struct Tree
    layers::Vector{TreeLayer}
end

mutable struct TreeGrowState
    nodeids::Vector{<:Integer}
    nodes::Vector{TreeNode}
    factors::Vector{<:AbstractFactor}
    ∂𝑙covariate::AbstractCovariate
    ∂²𝑙covariate::AbstractCovariate
    λ::Real
    γ::Real
    min∂²𝑙::Real
    slicelength::Integer
end
