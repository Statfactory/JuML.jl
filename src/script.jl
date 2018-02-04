using JuML

importcsv("src\\Data\\agaricus_train.csv"; isnumeric = (colname, _) -> colname == "label")

importcsv("src\\Data\\agaricus_test.csv"; isnumeric = (colname, _) -> colname == "label")

importcsv("src\\Data\\agaricus.csv")


traindf = DataFrame("src\\Data\\agaricus_train")
testdf = DataFrame("src\\Data\\agaricus_test")

f1 = traindf["cap-shape=bell"]
summary(f1)
f2 = map(f1, testdf)
summary(f2)


#class = df["class"]
#summary(class)

#label = JuML.CachedCovariate(JuML.ParseFactorCovariate("label", class, level -> level == "p" ? 1.0 : 0.0))
#factors = filter((x -> JuML.getname(x) != "class"), df.factors)

@time trees, pred = JuML.xgblogit(traindf["label"], traindf.factors; η = 1, nrounds = 1, maxdepth = 1, minchildweight = 0.0);

p = JuML.predict(trees, testdf, 1)
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