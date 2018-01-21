struct Factor{T<:Unsigned} <: AbstractFactor{T}
    name::String
    levels::AbstractVector{<:AbstractString}
    data::AbstractVector{T}
end

Base.length(factor::Factor{T}) where {T<:Unsigned} = length(factor.data)

function Factor(name::String, data::AbstractVector{<:AbstractString})
    maxlevelcount = length(unique(data))
    if maxlevelcount <= typemax(UInt8) + 1
        levelmap = Dict{String, UInt8}()
        levels = Vector{String}()
        resdata = Vector{UInt8}()
        for v in data
            if v == "" || v == MISSINGLEVEL
                push!(resdata, 0)
            else
                levelcount = length(levelmap)
                levelindex = get(levelmap, v, levelcount + 1)
                if levelindex > levelcount
                    push!(levels, v)
                end
                push!(resdata, levelindex)
            end
        end
        Factor{UInt8}(name, levels, resdata)
    elseif maxlevelcount <= typemax(UInt16) + 1
        levelmap = Dict{String, UInt16}()
        levels = Vector{String}()
        resdata = Vector{UInt16}()
        for v in data
            if v == "" || v == MISSINGLEVEL
                push!(resdata, 0)
            else
                levelcount = length(levelmap)
                levelindex = get(levelmap, v, levelcount + 1)
                if levelindex > levelcount
                    push!(levels, v)
                end
                push!(resdata, levelindex)
            end
        end
        Factor{UInt16}(name, levels, resdata)
    else
        levelmap = Dict{String, UInt32}()
        levels = Vector{String}()
        resdata = Vector{UInt32}()
        for v in data
            if v == "" || v == MISSINGLEVEL
                push!(resdata, 0)
            else
                levelcount = length(levelmap)
                levelindex = get(levelmap, v, levelcount + 1)
                if levelindex > levelcount
                    push!(levels, v)
                end
                push!(resdata, levelindex)
            end
        end
        Factor{UInt32}(name, levels, resdata)     
    end
end

function slice(factor::Factor{T}, fromobs::Integer, toobs::Integer, slicelength::Integer) where {T<:Unsigned}
    slice(factor.data, fromobs, toobs, slicelength)
end

