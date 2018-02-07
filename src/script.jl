using JuML

#@time importcsv("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetrain.csv")


#importcsv("src\\Data\\agaricus_train.csv"; isnumeric = (colname, _) -> colname == "label")

#importcsv("src\\Data\\agaricus_test.csv"; isnumeric = (colname, _) -> colname == "label")

#importcsv("src\\Data\\agaricus.csv")

airlinetraindf = DataFrame("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetrain"; preload = true)

traindf = DataFrame("src\\Data\\agaricus_train"; preload = true)
testdf = DataFrame("src\\Data\\agaricus_test"; preload = true)

df = DataFrame("src\\Data\\agaricus"; preload = true)

#airline:
label = covariate(airlinetraindf["dep_delayed_15min"], level -> level == "Y" ? 1.0f0 : 0.0f0)
deptime = factor(airlinetraindf["DepTime"], 1:2930)
distance = factor(airlinetraindf["Distance"], 11:4962)
factors = [filter((f -> getname(f) != "dep_delayed_15min"), airlinetraindf.factors); [deptime, distance]]

stats = getstats(airlinetraindf["dep_delayed_15min"])

summary(airlinetraindf["dep_delayed_15min"])

@time trees, pred = xgblogit(label, factors; η = 1, nrounds = 1, maxdepth = 5, caching = true, singlethread = true);



pred[1:5]
sum(pred)


#class = df["class"]
#summary(class)

#label = JuML.CachedCovariate(JuML.ParseFactorCovariate("label", class, level -> level == "p" ? 1.0 : 0.0))
#factors = filter((x -> JuML.getname(x) != "class"), df.factors)

#@time trees, pred = JuML.xgblogit(label, factors; η = 1, nrounds = 1, maxdepth = 1, minchildweight = 0.0, nthreads = 1);

@time trees, pred = JuML.xgblogit(traindf["label"], traindf.factors; η = 1, nrounds = 1, maxdepth = 1, minchildweight = 0.0, singlethread = true, slicelength = 5000);


p = predict(trees, testdf, 1)
sum(p)
sum(pred)



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

