using JuML

importcsv("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetrain.csv")

importcsv("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetest.csv")

train_df = DataFrame("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetrain") # note we are passing a path to a folder
test_df = DataFrame("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetest") 

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

factors = [train_df.factors; [deptime, distance]]
nfolds = 5
cvfolds = JuML.getnfolds(nfolds, false, length(label))
selector = BoolVariate("", cvfolds .!= UInt8(1) )

@time model = xgblogit(label, factors; selector = Nullable(selector), η = 1, λ = 1.0, γ = 0.0, minchildweight = 1.0, nrounds = 1, maxdepth = 5, caching = true, usefloat64 = false, singlethread = true);

@time cvmodel = JuML.cvxgblogit(label, factors, 5; η = 1, λ = 1.0, γ = 0.0, minchildweight = 1.0, nrounds = 1, maxdepth = 5, caching = true, usefloat64 = false, singlethread = true, slicelength = 10000);

res = predict(cvmodel.trees[1][1], train_df)
JuML.sigmoid.(res[1:5])
JuML.sigmoid.(cvmodel.cvpred[1:5])
model.pred[1:5]
@time pred = predict(model, test_df)
pred[1:5]
testlabel = covariate(test_df["dep_delayed_15min"], level -> level == "Y" ? 1.0 : 0.0)
auc = getauc(pred, testlabel)

x = [1.0, 2.0, 3.0]
y = x .== 1.0
z = view(y, 1:2)




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

system.time(md <- xgb.cv(data = dxgb_train, objective = "binary:logistic", nround = 1, max_depth = 10, eta = 1, tree_method='exact', nfold = 5, metrics= list("auc")))

