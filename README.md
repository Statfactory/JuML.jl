## JuML
JuML is a machine learning package written in pure Julia. This is still very much work in progress so the package is not registered yet and you will need to clone this repo to try it.

At the moment JuML contains a custom built *DataFrame* with associated types (*Factor*, *Covariate* etc) and an independent XGBoost implementation (logistic only). The XGBoost part around 600 lines of Julia code and has speed similar to the original C++ implementation with smaller memory footprint.

### Example usage: Airline dataset with 1M obs

The datasets can be downloaded from here: 

https://s3.amazonaws.com/benchm-ml--main/train-1m.csv

https://s3.amazonaws.com/benchm-ml--main/test.csv

Let's rename the datasets into *airlinetrain* and *airlinetest*.
First we have to import the csv datasets into a special binary format.
We will import both datasets into 1 *airlinetraintest* dataframe with test data stacked under train data:

```
using JuML
importcsv("your-path\\airlinetrain.csv"; path2 = "your-path\\airlinetest.csv", outname = "airlinetraintest")
```

The data will be converted into a special binary format and saved in a new folder named *airlinetraintest*. Each data column is stored in a separate binary file.

We can now load the dataset into JuML DataFrame:
```
traintest_df = DataFrame("your-path\\airlinetraintest") # note we are passing a path to a folder
```
You should see a summary of the dataframe in your REPL. JuML DataFrame is just a collection of Factors and Covariates. Categorical data is stored in Factors and numeric data in Covariates.

```
factors = traintest_df.factors
covariates = traintest_df.covariates
```
We can access each Factor or Covariate by name:
```
distance = traintest_df["Distance"]
deptime = traintest_df["DepTime"]
dep_delayed_15min = traintest_df["dep_delayed_15min"]
```

We can see a quick stat summary:
```
summary(distance)
summary(deptime)
summary(dep_delayed_15min)
```

JuML XGBoost expects label to be a Covariate and all features to be Factors. Our label is *dep_delayed_15min*, which is a Factor, and there are 2 Covariates in the data: *Distance* and *DepTime*. Fortunately we can easily convert between factors and covariates in JuML. 

Let's create a Covariate which is equal to 1 when *dep_delayed_15min* is Y and 0 otherwise:

```
label = covariate(traintest_df["dep_delayed_15min"], level -> level == "Y" ? 1.0 : 0.0)
```

Covariates can be converted into factors by binning. We can bin on every possible value with function *factor*:

```
deptime = factor(traintest_df["DepTime"])
distance = factor(traintest_df["Distance"])
```

We have stacked train and test data in 1 dataframe. We will need to define selectors for each part:
```
trainsel = BoolVariate("trainsel", (1:1100000) .<= 1000000)
validsel = BoolVariate("validsel", (1:1100000) .> 1000000)
```

The last thing to do before we can run XGBoost is to create a vector of factors as features. We need to add *deptime* and *distance* factors to train dataframe factors (*dep_delayed_15min* will be excluded from the model features automatically):

```
factors = [traintest_df.factors; [deptime, distance]]
```

We are now ready to run XGBoost:
```
model = xgblogit(label, factors; trainselector = trainsel, validselector = validsel, η = 0.3, λ = 1.0, γ = 0.0, minchildweight = 1.0, nrounds = 2, maxdepth = 5, ordstumps = false, caching = true, usefloat64 = true, singlethread = true);
```

We can now calculate auc and logloss for both train and validation:
```
trainauc, testauc = getauc(model.pred, label, trainsel, validsel)
trainlogloss, testlogloss = getlogloss(model.pred, label, trainsel, validsel)
```






