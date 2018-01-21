# function getslicer(fromobs::Integer, toobs::Integer, slicelength::Integer)
#     a = convert(Int64, fromobs)
#     slicelength = convert(Int64, slicelength)
#     b = a + slicelength - 1
#     c = b <= toobs ? b : toobs
#     () -> begin
#         if a <= c
#             res = Nullable{Tuple{Int64, Int64}}((a, c))
#             a = a + slicelength
#             b = a + slicelength - 1
#             c = b <= toobs ? b : toobs
#             res
#         else
#             Nullable{Tuple{Int64, Int64}}()
#         end
#     end
# end

function nextslice(ind::Tuple{Int64, Int64, Int64})
    fromobs = ind[1]
    toobs = ind[2]
    slicelength = ind[3]
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

function slice(data::AbstractVector{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T}
    if fromobs > toobs
        EmptySeq{AbstractVector{T}}()
    else
        fromobs = max(1, fromobs)
        toobs = min(toobs, length(data))
        slicelength = min(max(1, slicelength), toobs - fromobs + 1)
        buffer = Vector{T}(slicelength)
        map(Seq(Tuple{Int64, Int64}, (fromobs, toobs, slicelength), nextslice), AbstractVector{T}) do rng
            if rng[2] - rng[1] + 1 == slicelength
                map!(T, buffer, view(data, rng[1]:rng[2]))
                buffer
            else
                vw = view(buffer, 1:(rng[2] - rng[1] + 1))
                map!(T, vw, view(data, rng[1]:rng[2]))
                vw
            end
        end
    end
end

function mapslice(f::Function, slices::EmptySeq{AbstractVector{T}}, slicelength::Integer, ::Type{S}) where {T} where {S}
    EmptySeq{Vector{S}}()
end

function mapslice(f::Function, slices::ConsSeq{AbstractVector{T}}, slicelength::Integer, ::Type{S}) where {T} where {S}
    if T == S
        map(slices, AbstractVector{S}) do slice
            slice .= f.(slice)
            return slice
        end
    else
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
end

function mapslice2(f::Function, slices::EmptySeq{Tuple{AbstractVector{T}, AbstractVector{S}}}, slicelength::Integer, ::Type{U}) where {T} where {S} where {U}
    EmptySeq{Vector{U}}()
end

function mapslice2(f::Function, slices::ConsSeq{Tuple{AbstractVector{T}, AbstractVector{S}}}, slicelength::Integer, ::Type{U}) where {T} where {S} where {U}
    if T == U
        map(slices, AbstractVector{U}) do slice
            slice1 = slice[1]
            slice2 = slice[2]
            slice1 .= f.(slice1, slice2)
            return slice1
        end
    elseif S == U
        map(slices, AbstractVector{U}) do slice
            slice1 = slice[1]
            slice2 = slice[2]
            slice2 .= f.(slice1, slice2)
            return slice2
        end
    else
        buffer = Vector{U}(slicelength)
        map(slices, AbstractVector{U}) do slice
            slice1 = slice[1]
            slice2 = slice[2]
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
end

function mapslice3(f::Function, slices::EmptySeq{Tuple{AbstractVector{T}, AbstractVector{S}, AbstractVector{U}}}, slicelength::Integer, ::Type{V}) where {T} where {S} where {U} where {V}
    EmptySeq{Vector{V}}()
end

function mapslice3(f::Function, slices::ConsSeq{Tuple{AbstractVector{T}, AbstractVector{S}, AbstractVector{U}}}, slicelength::Integer, ::Type{V}) where {T} where {S} where {U} where {V}
    if T == V
        map(slices, AbstractVector{V}) do slice
            slice1 = slice[1]
            slice2 = slice[2]
            slice3 = slice[3]
            slice1 .= f.(slice1, slice2, slice3)
            return slice1
        end
    elseif S == V
        map(slices, AbstractVector{V}) do slice
            slice1 = slice[1]
            slice2 = slice[2]
            slice3 = slice[3]
            slice2 .= f.(slice1, slice2, slice3)
            return slice2
        end
    elseif U == V
        map(slices, AbstractVector{V}) do slice
            slice1 = slice[1]
            slice2 = slice[2]
            slice3 = slice[3]
            slice3 .= f.(slice1, slice2, slice3)
            return slice3
        end     
    else
        buffer = Vector{V}(slicelength)
        map(slices, AbstractVector{V}) do slice
            slice1 = slice[1]
            slice2 = slice[2]
            slice3 = slice[3]
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
end