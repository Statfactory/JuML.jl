push!(LOAD_PATH, "C:\\Users\\adamm\\Dropbox\\Development\\JuML\\src")
using JuML

importcsv("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetrain.csv")

importcsv("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetest.csv")

importcsv("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetrain.csv", path2 = "C:\\Users\\adamm_000\\Documents\\Julia\\airlinetest.csv")

train_df = DataFrame("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetrain") # note we are passing a path to a folder
test_df = DataFrame("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetest") 
traintest_df = DataFrame("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetrainairlinetest") 

factors = train_df.factors
covariates = train_df.covariates

distance = train_df["Distance"]
deptime = train_df["DepTime"]
dep_delayed_15min = train_df["dep_delayed_15min"]

summary(distance)
summary(deptime)
summary(dep_delayed_15min)

label = covariate(train_df["dep_delayed_15min"], level -> level == "Y" ? 1.0 : 0.0)

deptime = factor(train_df["DepTime"], 1:2930)
distance = factor(train_df["Distance"], 11:4962)

islessf = (x, y) -> parse(x[3:end]) < parse(y[3:end])
month = JuML.OrdinalFactor("Month", train_df["Month"], islessf)
dayofMonth = JuML.OrdinalFactor("DayofMonth", train_df["DayofMonth"], islessf)
dayOfWeek = JuML.OrdinalFactor("DayOfWeek", train_df["DayOfWeek"], islessf)
uniqueCarrier = JuML.OrdinalFactor(train_df["UniqueCarrier"])
origin = JuML.OrdinalFactor(train_df["Origin"])
dest = JuML.OrdinalFactor(train_df["Dest"])

#factors = [[month, dayofMonth, dayOfWeek, uniqueCarrier, origin, dest]; [deptime, distance]]

factors = [train_df.factors; [deptime, distance]]

trainsel = (1:10100000) .<= 10000000
testsel = (1:10100000) .> 10000000

@time model = xgblogit(label, factors; η = 0.1, λ = 1.0, γ = 0.0, minchildweight = 1.0, nrounds = 100, maxdepth = 10, ordstumps = false, pruning = true, caching = true, usefloat64 = false, singlethread = false, slicelength = 0);

pred = predict(model, test_df)
testlabel = covariate(test_df["dep_delayed_15min"], level -> level == "Y" ? 1.0 : 0.0)
trainauc = getauc(model.pred, label;selector = trainsel)
testauc = getauc(model.pred, label;selector = testsel)

auc = getauc(pred, testlabel)

logloss = getlogloss(pred, testlabel)

@time cv = cvxgblogit(label, factors, 5; aucmetric = true, loglossmetric = true, trainmetric = true, η = 0.3, λ = 1.0, γ = 0.0, minchildweight = 1.0, nrounds = 2, maxdepth = 5, ordstumps = true, caching = true, usefloat64 = true, singlethread = true);
cv
model.pred[1:5]
@time pred = predict(model, test_df)

pred[1:5]
testlabel = covariate(test_df["dep_delayed_15min"], level -> level == "Y" ? 1.0 : 0.0)

@time auc = getauc(pred, testlabel)


#importcsv("src\\Data\\agaricus_train.csv"; isnumeric = (colname, _) -> colname == "label")

#importcsv("src\\Data\\agaricus_test.csv"; isnumeric = (colname, _) -> colname == "label")

#importcsv("src\\Data\\agaricus.csv")

traindf = DataFrame("src\\Data\\agaricus_train"; preload = true)
testdf = DataFrame("src\\Data\\agaricus_test"; preload = true)

df = DataFrame("src\\Data\\agaricus"; preload = true)

#class = df["class"]
#summary(class)

#label = JuML.CachedCovariate(JuML.ParseFactorCovariate("label", class, level -> level == "p" ? 1.0 : 0.0))
#factors = filter((x -> JuML.getname(x) != "class"), df.factors)

#@time trees, pred = JuML.xgblogit(label, factors; η = 1, nrounds = 1, maxdepth = 1, minchildweight = 0.0, nthreads = 1);

@time model = JuML.xgblogit(traindf["label"], traindf.factors; η = 1, nrounds = 1, maxdepth = 1, minchildweight = 0.0, singlethread = true, slicelength = 5000);


R:
require(xgboost)
data(agaricus.train, package='xgboost')
train <- agaricus.train
data(agaricus.test, package='xgboost')
test <- agaricus.test
model <- xgboost(data = train$data, label = train$label, eta = 1, nrounds = 1, max_depth = 1, objective = "binary:logistic")
preds = predict(model, train$data)

airline:
suppressMessages({
library(data.table)
library(ROCR)
library(xgboost)
library(Matrix)
})
set.seed(123)
d_train <- fread("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetrain.csv", showProgress=FALSE, stringsAsFactors=TRUE)
X_train <- sparse.model.matrix(dep_delayed_15min ~ .-1, data = d_train)
dxgb_train <- xgb.DMatrix(data = X_train, label = ifelse(d_train$dep_delayed_15min=='Y',1,0))
system.time(md <- xgb.train(data = dxgb_train, objective = "binary:logistic", nround = 1, max_depth = 2, eta = 1, tree_method='exact'))
preds = predict(md, dxgb_train)
xgb.plot.tree(model = md, feature_names = colnames(dxgb_train))

library(MLmetrics)
phat <- predict(md, newdata = X_test)
AUC(phat, testlabel)

system.time(md <- xgb.cv(data = dxgb_train, objective = "binary:logistic", nround = 1, max_depth = 10, eta = 1, tree_method='exact', nfold = 5, metrics= list("auc")))

