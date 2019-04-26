push!(LOAD_PATH, joinpath(pwd(), "src"))
using JuML
using Test


traintest_df = DataFrame(joinpath("data", "airlinetraintest")) 
distance = traintest_df["Distance"]
deptime = traintest_df["DepTime"]
label = covariate(traintest_df["dep_delayed_15min"], level -> level == "Y" ? 1.0 : 0.0)
deptime = factor(traintest_df["DepTime"])
distance = factor(traintest_df["Distance"])

factors = [traintest_df.factors; [deptime, distance]] 

trainsel = BoolVariate("trainsel", (1:1100000) .<= 1000000)
validsel = BoolVariate("validsel", (1:1100000) .> 1000000)

model1 = xgblogit(label, factors; trainselector = trainsel, validselector = validsel,  η = 1, λ = 1.0, γ = 0.0, minchildweight = 1.0, nrounds = 1, maxdepth = 1, ordstumps = false, pruning = false, caching = true, usefloat64 = true, singlethread = true, slicelength = 0);
_, testauc1 = getauc(model1.pred, label, trainsel, validsel)
@test testauc1 ≈ 0.634631 atol = 0.0000001

model2 = xgblogit(label, factors; trainselector = trainsel, validselector = validsel, η = 0.1, λ = 1.0, γ = 0.0, minchildweight = 1.0, nrounds = 2, maxdepth = 2, ordstumps = false, pruning = false, caching = true, usefloat64 = true, singlethread = true, slicelength = 0);
_, testauc2 = getauc(model2.pred, label, trainsel, validsel)
@test testauc2 ≈ 0.6749474 atol = 0.0000001

model3 = xgblogit(label, factors; trainselector = trainsel, validselector = validsel, η = 1, λ = 1.0, γ = 0.0, minchildweight = 1000.0, nrounds = 1, maxdepth = 6, ordstumps = false, pruning = false, caching = true, usefloat64 = true, singlethread = false, slicelength = 0);
_, testauc3 = getauc(model3.pred, label, trainsel, validsel)
@test testauc3 ≈ 0.7002925 atol = 0.0000001

model4 = xgblogit(label, factors; trainselector = trainsel, validselector = validsel, η = 1, λ = 1.0, γ = 500.0, minchildweight = 1.0, nrounds = 1, maxdepth = 4, ordstumps = false, pruning = false, caching = true, usefloat64 = true, singlethread = false, slicelength = 0);
_, testauc4 = getauc(model4.pred, label, trainsel, validsel)
@test testauc4 ≈ 0.6888606 atol = 0.0000001

model5 = xgblogit(label, factors; trainselector = trainsel, validselector = validsel, η = 0.1, λ = 1.0, γ = 0.0, minchildweight = 1.0, nrounds = 10, maxdepth = 10, ordstumps = false, pruning = false, caching = true, usefloat64 = true, singlethread = true, slicelength = 0);
_, testauc5 = getauc(model5.pred, label, trainsel, validsel)
@test testauc5 ≈ 0.7255029 atol = 0.0002

#model6 = xgblogit(label, factors; trainselector = trainsel, validselector = validsel,  η = 1, λ = 1.0, γ = 0.0, minchildweight = 0.0, nrounds = 1, maxdepth = 6, ordstumps = false, pruning = false, leafwise = true, maxleaves = 64, caching = true, usefloat64 = true, singlethread = false, slicelength = 0);
#_, testauc6 = getauc(model6.pred, label, trainsel, validsel)
#@test testauc6 ≈ 0.7004898 atol = 0.0000001

# XGBoost R script to compare:
# Data:
# wget https://s3.amazonaws.com/benchm-ml--main/train-1m.csv
# wget https://s3.amazonaws.com/benchm-ml--main/train-10m.csv
# wget https://s3.amazonaws.com/benchm-ml--main/test.csv

# suppressMessages({
# library(data.table)
# library(ROCR)
# library(xgboost)
# library(MLmetrics)
# library(Matrix)
# })

# d_train <- fread("C:\\Users\\adamm\\Documents\\julia\\airlinetrain1m.csv", showProgress=FALSE, stringsAsFactors=TRUE)
# d_test <- fread("C:\\Users\\adamm\\Documents\\julia\\airlinetest.csv", showProgress=FALSE, stringsAsFactors=TRUE)
# X_train_test <- sparse.model.matrix(dep_delayed_15min ~ .-1, data = rbind(d_train, d_test))
# n1 <- nrow(d_train)
# n2 <- nrow(d_test)
# X_train <- X_train_test[1:n1,]
# X_test <- X_train_test[(n1+1):(n1+n2),]
# dxgb_train <- xgb.DMatrix(data = X_train, label = ifelse(d_train$dep_delayed_15min=='Y',1,0))
# md <- xgb.train(data = dxgb_train, objective = "binary:logistic", nround = 1, max_depth = 1, eta = 1.0, tree_method='exact')
# # md <- xgb.train(data = dxgb_train, objective = "binary:logistic", nround = 10, max_depth = 10, eta = 0.1, tree_method='hist', grow_policy='lossguide', max_leaves=256, max_bin=5000)
# phat <- predict(md, newdata = X_test)
# testlabel = ifelse(d_test$dep_delayed_15min=='Y',1,0)
# AUC(phat, testlabel)