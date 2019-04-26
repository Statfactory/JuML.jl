using Compat, Compat.Test
push!(LOAD_PATH, joinpath(pwd(), "src"))
using JuML
using Test
using Random

data = bitrand(10)
boolvar = BoolVariate("boolvar", data)
@test length(boolvar) == 10
@test getname(boolvar) == "boolvar"

data2 = convert(Vector{Bool}, boolvar)
@test isa(data2, Vector{Bool})