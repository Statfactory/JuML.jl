abstract type Tree{T} end

struct EmptyTree{T} <: Tree{T} end

struct ConsTree{T} <: Tree{T}
     value::T
     lefttree::Tree{T}
     righttree::Tree{T}
 end

 function ConsTree{T}(value::T) where {T}
    ConsTree{T}(value, EmptyTree{T}(), EmptyTree{T}())
 end

 function Base.isempty(tree::EmptyTree{T}) where {T}
     true
 end

 function Base.isempty(tree::ConsTree{T}) where {T}
    false
end