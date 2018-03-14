using Compat, Compat.Test
using JuML

data = bitrand(10)
boolvar = BoolVariate("boolvar", data)
@test length(boolvar) == 10
@test getname(boolvar) == "boolvar"

data2 = convert(BitArray, boolvar)
isa(data, Vector{Bool})