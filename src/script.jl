push!(LOAD_PATH, joinpath(pwd(), "src"))

using JuML
using Pkg

#fannie headers:
colnames = ["loan_id", "monthly_rpt_prd", "servicer_name", "last_rt", "last_upb", "loan_age",
    "months_to_legal_mat" , "adj_month_to_mat", "maturity_date", "msa", "delq_status",
    "mod_flag", "zero_bal_code", "zb_dte", "lpi_dte", "fcc_dte","disp_dt", "fcc_cost",
    "pp_cost", "ar_cost", "ie_cost", "tax_cost", "ns_procs", "ce_procs", "rmw_procs",
    "o_procs", "non_int_upb", "prin_forg_upb_fhfa", "repch_flag", "prin_forg_upb_oth",
    "transfer_flg"]

importcsv("E:\\FannieMae\\Performance_All\\Performance_2017Q4.txt"; sep = "|", colnames = colnames,
           isinteger = ((colname, freq) -> colname == "loan_id"), 
           isdatetime = ((colname, freq) ->
                            if colname == "monthly_rpt_prd" || colname == "lpi_dte" || colname == "fcc_dte" || colname == "disp_dt"
                                true, "mm/dd/yyyy"
                            elseif colname == "maturity_date" || colname == "zb_dte"
                                true, "mm/yyyy"
                            else
                                false, ""
                            end
                        ));

fannie_df = DataFrame("E:\\FannieMae\\Performance_All\\Performance_2017Q4"; preload = false)
v = fannie_df["loan_id"]
s = summary(fannie_df["zb_dte"])

importcsv("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetest.csv")

importcsv("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetrain.csv", path2 = "C:\\Users\\adamm_000\\Documents\\Julia\\airlinetest.csv")

train_df = DataFrame("C:\\Users\\adamm\\Documents\\Julia\\airlinetrain1m") # note we are passing a path to a folder
test_df = DataFrame("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetest") 
traintest_df = DataFrame("C:\\Users\\adamm\\Documents\\Julia\\airlinetrainairlinetest") 

factors = traintest_df.factors
covariates = traintest_df.covariates

distance = traintest_df["Distance"]
deptime = traintest_df["DepTime"]
dep_delayed_15min = traintest_df["dep_delayed_15min"]

summary(distance)
summary(deptime)
summary(dep_delayed_15min)

label = covariate(traintest_df["dep_delayed_15min"], level -> level == "Y" ? 1.0 : 0.0)

deptime = factor(traintest_df["DepTime"])
distance = factor(traintest_df["Distance"])

# islessf = (x, y) -> parse(x[3:end]) < parse(y[3:end])
# month = JuML.OrdinalFactor("Month", traintest_df["Month"], islessf)
# dayofMonth = JuML.OrdinalFactor("DayofMonth", traintest_df["DayofMonth"], islessf)
# dayOfWeek = JuML.OrdinalFactor("DayOfWeek", traintest_df["DayOfWeek"], islessf)
# uniqueCarrier = JuML.OrdinalFactor(traintest_df["UniqueCarrier"])
# origin = JuML.OrdinalFactor(traintest_df["Origin"])
# dest = JuML.OrdinalFactor(traintest_df["Dest"])

# factors = [[month, dayofMonth, dayOfWeek, uniqueCarrier, origin, dest]; [deptime, distance]]

#factors = [traintest_df.factors; [deptime, distance]]

trainsel = BoolVariate("", (1:10100000) .<= 10000000)
testsel = BoolVariate("", (1:10100000) .> 10000000)

@time model = xgblogit(label, [factors; [deptime, distance]]; trainselector = trainsel, validselector = testsel, η = 0.1, λ = 1.0, γ = 0.0, minchildweight = 1.0, nrounds = 100, maxdepth = 10, leafwise = true, maxleaves = 256, ordstumps = true, pruning = false, caching = true, usefloat64 = true, singlethread = false, slicelength = 0);

#@time pred = predict(model, test_df)
#testlabel = covariate(test_df["dep_delayed_15min"], level -> level == "Y" ? 1.0 : 0.0)

 trainauc, testauc = getauc(model.pred, label, trainsel, testsel)

trainlogloss = getlogloss(model.pred, label;selector = trainsel)
testlogloss = getlogloss(model.pred, label; selector = testsel)

auc = getauc(pred, testlabel)
sum(model.pred[testsel])

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

levelmap = Dict{SubString{String}, Int64}()

line = "as, cd, er"
v = split(line, ",")
colnames = map((c -> strip(strip(c), ['"'])), v)


cols = Set{SubString{String}}(colnames)
line2 = "as, cd, er"
v2 = split(line2, ",")
colnames2 = map((c -> strip(strip(c), ['"'])), v2)

levelcount = length(levelmap)
levelindex = get(levelmap, colnames[2], levelcount)

levelmap[colnames2[2]] = levelindex
levelmap
colnames[2]

colnames2[1] in cols

v3 = "as"
v3 in cols

arr = zeros(UInt8, 10)
arr2 = convert(Vector{UInt16}, arr)

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
library(MLmetrics)
library(Matrix)
})
set.seed(123)
d_train <- fread("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetrain.csv", showProgress=FALSE, stringsAsFactors=TRUE)
d_test <- fread("C:\\Users\\adamm_000\\Documents\\Julia\\airlinetest.csv", showProgress=FALSE, stringsAsFactors=TRUE)

X_train_test <- sparse.model.matrix(dep_delayed_15min ~ .-1, data = rbind(d_train, d_test))
n1 <- nrow(d_train)
n2 <- nrow(d_test)
X_train <- X_train_test[1:n1,]
X_test <- X_train_test[(n1+1):(n1+n2),]

dxgb_train <- xgb.DMatrix(data = X_train, label = ifelse(d_train$dep_delayed_15min=='Y',1,0))

system.time(md <- xgb.train(data = dxgb_train, objective = "binary:logistic", nround = 1, max_depth = 2, eta = 1, tree_method='exact'))
preds = predict(md, dxgb_train)

xgb.plot.tree(model = md, feature_names = colnames(dxgb_train))

phat <- predict(md, newdata = X_test)
AUC(phat, testlabel)

system.time(md <- xgb.cv(data = dxgb_train, objective = "binary:logistic", nround = 1, max_depth = 10, eta = 1, tree_method='exact', nfold = 5, metrics= list("auc")))

