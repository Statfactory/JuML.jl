function nextslice(ind::Tuple{Int64, Int64, Int64})
    fromobs, toobs, slicelength = ind
    sliceend = min(toobs, fromobs + slicelength - 1)
    if fromobs <= sliceend
        Nullable((fromobs, sliceend)), (sliceend + 1, toobs, slicelength)
    else
        Nullable{Tuple{Int64, Int64}}(), ind
    end
end

function nextdatachunk(state::Tuple{Vector{T}, IOStream, Integer, Integer, Integer}) where {T}
    buffer, iostream, fromobs, toobs, slicelength = state
    slicelength = verifyslicelength(fromobs, toobs, slicelength) 
    if eof(iostream) || slicelength == 0
        close(iostream)
        Nullable{Vector{T}}(), state
    else
        buffer = resize!(buffer, slicelength)
        read!(iostream, buffer)
        Nullable{Vector{T}}(buffer), (buffer, iostream, fromobs + slicelength, toobs, slicelength)
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
    toobs < fromobs || slicelength <= 0 ? 0 : min(slicelength, toobs - fromobs + 1)
end

function slice(data::Vector{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T}
    if fromobs > toobs
        EmptySeq{SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}}()
    else
        fromobs = max(1, fromobs)
        toobs = min(toobs, length(data))
        slicelength = verifyslicelength(fromobs, toobs, slicelength)
        map(Seq(Tuple{Int64, Int64}, (fromobs, toobs, slicelength), nextslice), SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}) do rng
                from, to = rng
                view(data, from:to)
        end
    end
end

function slice(data::SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T}
    if fromobs > toobs
        EmptySeq{SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}}()
    else
        fromobs = max(1, fromobs)
        toobs = min(toobs, length(data))
        slicelength = verifyslicelength(fromobs, toobs, slicelength)
        map(Seq(Tuple{Int64, Int64}, (fromobs, toobs, slicelength), nextslice), SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}) do rng
                from, to = rng
                view(data, from:to)
        end
    end
end

function slice(data::SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}, fromobs::Integer, toobs::Integer, slicelength::Integer) 
    if fromobs > toobs
        EmptySeq{SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}}()
    else
        fromobs = max(1, fromobs)
        toobs = min(toobs, length(data))
        slicelength = verifyslicelength(fromobs, toobs, slicelength)
        map(Seq(Tuple{Int64, Int64}, (fromobs, toobs, slicelength), nextslice), SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}) do rng
                from, to = rng
                view(data, from:to)
        end
    end
end

function mapslice(f::Function, slices::EmptySeq{SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}}, slicelength::Integer, ::Type{S}) where {S}
    if S == Bool
        EmptySeq{SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}}()
    else
        EmptySeq{SubArray{S,1,Array{S,1},Tuple{UnitRange{Int64}},true}}()
    end
end

function mapslice(f::Function, slices::ConsSeq{SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}}, slicelength::Integer, ::Type{S}) where {S}
    if S == Bool
        buffer = BitArray{1}(slicelength)
        map(slices, SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}) do slice
            v = view(buffer, 1:length(slice))
            v .= f.(slice)
            return v
        end  
    else
        buffer = Vector{S}(slicelength)
        map(slices, SubArray{S,1,Array{S,1},Tuple{UnitRange{Int64}},true}) do slice
            v = view(buffer, 1:length(slice))
            v .= f.(slice)
            return v
        end  
    end
end

function mapslice(f::Function, slices::EmptySeq{SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}}, slicelength::Integer, ::Type{S}) where {T} where {S}
    EmptySeq{SubArray{S,1,Array{S,1},Tuple{UnitRange{Int64}},true}}()
end

function mapslice(f::Function, slices::ConsSeq{SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}}, slicelength::Integer, ::Type{S}) where {T} where {S}
    buffer = Vector{S}(slicelength)
    map(slices, SubArray{S,1,Array{S,1},Tuple{UnitRange{Int64}},true}) do slice
        v = view(buffer, 1:length(slice))
        v .= f.(slice)
        return v
    end       
end

function mapslice2(f::Function, slices::EmptySeq{Tuple{SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}, SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}}}, slicelength::Integer, ::Type{U}) where {U}
    if U == Bool
        EmptySeq{SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}}()
    else
        EmptySeq{SubArray{U,1,Array{U,1},Tuple{UnitRange{Int64}},true}}()
    end
end

function mapslice2(f::Function, slices::ConsSeq{Tuple{SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}, SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}}}, slicelength::Integer, ::Type{U}) where {U}
    if U == Bool
        buffer = BitArray{1}(slicelength)
        map(slices, SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}) do slice
            slice1, slice2 = slice
            v = view(buffer, 1:length(slice1))
            v .= f.(slice1, slice2)
            return v
        end 
    else
        buffer = Vector{U}(slicelength)
        map(slices, SubArray{U,1,Array{U,1},Tuple{UnitRange{Int64}},true}) do slice
            slice1, slice2 = slice
            v = view(buffer, 1:length(slice1))
            v .= f.(slice1, slice2)
            return v
        end 
    end
end

function mapslice2(f::Function, slices::EmptySeq{Tuple{SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}, SubArray{S,1,Array{S,1},Tuple{UnitRange{Int64}},true}}}, slicelength::Integer, ::Type{U}) where {T} where {S} where {U}
    EmptySeq{SubArray{U,1,Array{U,1},Tuple{UnitRange{Int64}},true}}()
end

function mapslice2(f::Function, slices::ConsSeq{Tuple{SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}, SubArray{S,1,Array{S,1},Tuple{UnitRange{Int64}},true}}}, slicelength::Integer, ::Type{U}) where {T} where {S} where {U}
    buffer = Vector{U}(slicelength)
    map(slices, SubArray{U,1,Array{U,1},Tuple{UnitRange{Int64}},true}) do slice
        slice1, slice2 = slice
        v = view(buffer, 1:length(slice1))
        v .= f.(slice1, slice2)
        return v
    end       
end

function mapslice3(f::Function, slices::EmptySeq{Tuple{SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}, SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}, SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}}}, slicelength::Integer, ::Type{V}) where {V}
    if V == Bool
        EmptySeq{SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}}()
    else
        EmptySeq{SubArray{V,1,Array{V,1},Tuple{UnitRange{Int64}},true}}()
    end
end

function mapslice3(f::Function, slices::ConsSeq{Tuple{SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}, SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}, SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}}}, slicelength::Integer, ::Type{V}) where {V}
    if V == Bool
        buffer = BitArray{1}(slicelength)
        map(slices, SubArray{Bool,1,BitArray{1},Tuple{UnitRange{Int64}},true}) do slice
            slice1, slice2, slice3 = slice
            v = view(buffer, 1:length(slice1))
            v .= f.(slice1, slice2, slice3)
            return v
        end 
    else
        buffer = Vector{V}(slicelength)
        map(slices, SubArray{V,1,Array{V,1},Tuple{UnitRange{Int64}},true}) do slice
            slice1, slice2, slice3 = slice
            v = view(buffer, 1:length(slice1))
            v .= f.(slice1, slice2, slice3)
            return v
        end 
    end
end

function mapslice3(f::Function, slices::EmptySeq{Tuple{SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}, SubArray{S,1,Array{S,1},Tuple{UnitRange{Int64}},true}, SubArray{U,1,Array{U,1},Tuple{UnitRange{Int64}},true}}}, slicelength::Integer, ::Type{V}) where {T} where {S} where {U} where {V}
    EmptySeq{SubArray{V,1,Array{V,1},Tuple{UnitRange{Int64}},true}}()
end

function mapslice3(f::Function, slices::ConsSeq{Tuple{SubArray{T,1,Array{T,1},Tuple{UnitRange{Int64}},true}, SubArray{S,1,Array{S,1},Tuple{UnitRange{Int64}},true}, SubArray{U,1,Array{U,1},Tuple{UnitRange{Int64}},true}}}, slicelength::Integer, ::Type{V}) where {T} where {S} where {U} where {V}
    buffer = Vector{V}(slicelength)
    map(slices, SubArray{V,1,Array{V,1},Tuple{UnitRange{Int64}},true}) do slice
        slice1, slice2, slice3 = slice
        v = view(buffer, 1:length(slice1))
        v .= f.(slice1, slice2, slice3)
        return v
    end       
end

function getnfolds(n::Integer, stratified::Bool, len::Integer)
    n = UInt8(n)
    #len = length(label)
    perm = randperm(len)
    res = Vector{UInt8}(len)
    if stratified 
        #stats = getstats(label)

    else
        space = map((x -> Int64(floor(x))), LinSpace(1, len, n + 1))
        obs = 1
        for i in 1:n
            from = i == 1 ? space[i] : space[i] + 1
            to = space[i + 1]
            for j in from:to
                res[perm[obs]] = i
                obs += 1
            end
        end
    end
    res
end

