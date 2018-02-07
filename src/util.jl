
function nextslice(ind::Tuple{Int64, Int64, Int64})
    fromobs, toobs, slicelength = ind
    sliceend = min(toobs, fromobs + slicelength - 1)
    if fromobs <= sliceend
        Nullable((fromobs, sliceend)), (sliceend + 1, toobs, slicelength)
    else
        Nullable{Tuple{Int64, Int64}}(), ind
    end
end

function nextline(iostream::IOStream)
    if eof(iostream)
        close(iostream)
        Nullable{String}(), iostream
    else
        Nullable{String}(readline(iostream)), iostream
    end
end

function verifyslicelength(fromobs::Integer, toobs::Integer, slicelength::Integer)
    toobs < fromobs || slicelength <= 0? 0 : min(slicelength, toobs - fromobs + 1)
end

function slice(data::AbstractVector{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T}
    if fromobs > toobs
        EmptySeq{AbstractVector{T}}()
    else
        fromobs = max(1, fromobs)
        toobs = min(toobs, length(data))
        slicelength = verifyslicelength(fromobs, toobs, slicelength)
    buffer = Vector{T}(slicelength)
        map(Seq(Tuple{Int64, Int64}, (fromobs, toobs, slicelength), nextslice), AbstractVector{T}) do rng
                from, to = rng
                view(data, from:to)
        end
    end
end

function mapslice(f::Function, slices::EmptySeq{AbstractVector{T}}, slicelength::Integer, ::Type{S}) where {T} where {S}
    EmptySeq{Vector{S}}()
end

function mapslice(f::Function, slices::ConsSeq{AbstractVector{T}}, slicelength::Integer, ::Type{S}) where {T} where {S}
    buffer = Vector{S}(slicelength)
    map(slices, AbstractVector{S}) do slice
        if length(slice) == slicelength
            buffer .= f.(slice)
            return buffer
        else
            v = view(buffer, 1:length(slice))
            v .= f.(slice)
            return v
        end
    end       
end

function mapslice2(f::Function, slices::EmptySeq{Tuple{AbstractVector{T}, AbstractVector{S}}}, slicelength::Integer, ::Type{U}) where {T} where {S} where {U}
    EmptySeq{Vector{U}}()
end

function mapslice2(f::Function, slices::ConsSeq{Tuple{AbstractVector{T}, AbstractVector{S}}}, slicelength::Integer, ::Type{U}) where {T} where {S} where {U}
    buffer = Vector{U}(slicelength)
    map(slices, AbstractVector{U}) do slice
        slice1, slice2 = slice
        if length(slice1) == slicelength
            buffer .= f.(slice1, slice2)
            return buffer
        else
            v = view(buffer, 1:length(slice1))
            v .= f.(slice1, slice2)
            return v
        end
    end       
end

function mapslice3(f::Function, slices::EmptySeq{Tuple{AbstractVector{T}, AbstractVector{S}, AbstractVector{U}}}, slicelength::Integer, ::Type{V}) where {T} where {S} where {U} where {V}
    EmptySeq{Vector{V}}()
end

function mapslice3(f::Function, slices::ConsSeq{Tuple{AbstractVector{T}, AbstractVector{S}, AbstractVector{U}}}, slicelength::Integer, ::Type{V}) where {T} where {S} where {U} where {V}
    buffer = Vector{V}(slicelength)
    map(slices, AbstractVector{V}) do slice
        slice1, slice2, slice3 = slice
        if length(slice1) == slicelength
            buffer .= f.(slice1, slice2, slice3)
            return buffer
        else
            v = view(buffer, 1:length(slice1))
            v .= f.(slice1, slice2, slice3)
            return v
        end
    end       
end

