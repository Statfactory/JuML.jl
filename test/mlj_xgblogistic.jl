push!(LOAD_PATH, joinpath(pwd(), "src"))
using JuML
using Test
using MLJ
import MLJBase
import DataFrames
import CSV


# train_df = DataFrame(joinpath("data", "airlinetrain")) 
# test_df = DataFrame(joinpath("data", "airlinetest")) 

# distance = train_df[:Distance]
# deptime = train_df[:DepTime]

# deptime = factor(train_df[:DepTime])
# distance = factor(train_df[:Distance])

# factors = [train_df.factors; [deptime, distance]]

# label = train_df[:dep_delayed_15min]

# model = XGBClassifier(maxdepth = 2, nrounds = 5)

# mach = machine(model, factors, label)
# fit!(mach; force = true)

# yhat = MLJ.predict(mach, train_df)

df = CSV.read(abspath(joinpath("data", "airlinetrain1M.csv")))

DataFrames.names(df)
DataFrames.categorical!(df, [1, 2, 3, 5, 6, 7, 9])

train_df = JuML.DataFrame(df) 

distance = train_df["Distance"]
deptime = train_df["DepTime"]
label = covariate(train_df["dep_delayed_15min"], level -> level == "Y" ? 1.0 : 0.0)
deptime = factor(train_df["DepTime"])
distance = factor(train_df["Distance"])

factors = [train_df.factors; [deptime, distance]]

@time model7 = xgblogit(label, factors; η = 0.1, λ = 1.0, γ = 0.0, minchildweight = 1.0, nrounds = 100, maxdepth = 8, ordstumps = false, pruning = false, caching = true, usefloat64 = false, singlethread = true, slicelength = 0);
auc = getauc(model7.pred, label)
model7.pred[1:5]

