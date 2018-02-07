## JuML
JuML is a machine learning package written in pure Julia. This is still very much work in progress so the package is not registered yet and you will need to clone this repo to try it.

At the moment JuML contains a custom built *DataFrame* with associated types (*Factor*, *Covariate* etc) and an independent XGBoost implementation (logistic only). The XGBoost part is under 500 lines of Julia code and has speed similar to the original C++ implementation with smaller memory footprint.

### Example usage: Airline dataset with 10M obs

The datasets can be downloaded from here: 

https://s3.amazonaws.com/benchm-ml--main/train-10m.csv

https://s3.amazonaws.com/benchm-ml--main/test.csv

Let's rename the datasets into *airlinetrain* and *airlinetest*.
First we have to import the csv datasets into a special binary format:

```
using JuML
importcsv("your-path\\airlinetrain.csv")
importcsv("your-path\\airlinetest.csv")
```

The data will be converted into a special binary format and saved in a new folder named after the name of the csv file, e.g. *airlinetrain*. Each data column is stored in a separate binary file.

We can now load the datasets into JuML DataFrames:
```
train_df = DataFrame("your-path\\airlinetrain") # note we are passing a path to a folder
test_df = DataFrame("your-path\\airlinetest") 
```
You should see a summary of the dataframe in your REPL. JuML DataFrame is just a collection of Factors and Covariates. Categorical data is stored in Factors and numeric data in Covariates.

```
factors = train_df.factors
covariates = train_df.covariates
```
We can access each Factor or Covariate by name:
```
distance = train_df["Distance"]
deptime = train_df["DepTime"]
dep_delayed_15min = train_df["dep_delayed_15min"]
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
label = covariate(train_df["dep_delayed_15min"], level -> level == "Y" ? 1.0 : 0.0)
```

Covariates can be converted into factors by binning. From the summary of our covariates we know that *Distance* values range from 11 to 4962 and *DepTime* from 1 to 2930. We can simply apply those ranges to create factors:

```
deptime = factor(train_df["DepTime"], 1:2930)
distance = factor(train_df["Distance"], 11:4962)
```

Last thing to do before we can run XGBoost is to create a vector of factors as features. We need to exclude *dep_delayed_15min* from the train DataFrame factors and add *deptime* and *distance* factors:

```
factors = [filter((f -> getname(f) != "dep_delayed_15min"), train_df.factors); [deptime, distance]]
```

We are now ready to run XGBoost:
```
model = xgblogit(label, factors; η = 1, λ = 1.0, γ = 0.0, minchildweight = 1.0, nrounds = 1, maxdepth = 5, caching = true, singlethread = true);
```

We can apply the model to our test data now:
```
pred = predict(model, test_df)
```




