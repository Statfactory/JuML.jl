using JuML

#importcsv("src\\Data\\agaricus_train.csv", 100000, 10000, (colname, _) -> colname == "label")

#importcsv("src\\Data\\agaricus.csv", 100000, 10000)

headerPath = "src\\Data\\agaricus_train\\header.txt"

df = DataFrame(headerPath)

#class = df["class"]
#summary(class)

#label = JuML.CachedCovariate(JuML.ParseFactorCovariate("label", class, level -> level == "p" ? 1.0 : 0.0))
#factors = filter((x -> JuML.getname(x) != "class"), df.factors)

@time xgb = JuML.xgblogit(df["label"], df.factors; η = 1, nrounds = 1, maxdepth = 1, minchildweight = 0.0);
tree, pred = xgb;

pred[1:5]
sum(pred)



R:
require(xgboost)
data(agaricus.train, package='xgboost')
train <- agaricus.train
model <- xgboost(data = train$data, label = train$label, eta = 1, nrounds = 1, max_depth = 1, objective = "binary:logistic", verbose = 2)
preds = predict(model, train$data)