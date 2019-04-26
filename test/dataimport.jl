push!(LOAD_PATH, joinpath(pwd(), "src"))
using Test
using JuML

train1Mcsv = joinpath("data", "airlinetrain1m.csv")
testcsv = joinpath("data", "airlinetest.csv")

importcsv(train1Mcsv; path2 = testcsv, outname = "airlinetraintest")

traintest_df = DataFrame(joinpath("data", "airlinetraintest"))

@test length(traintest_df.covariates) == 2

@test length(traintest_df.factors) == 7


