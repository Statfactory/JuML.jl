__precompile__(true)
module JuML
export importcsv,
       Seq,
       DataFrame,
       Factor,
       Covariate,
       BoolVariate,
       DateTimeVariate,
       factor,
       covariate,
       getname,
       getlevels,
       isordinal,
       xgblogit,
       cvxgblogit,
       predict,
       getstats,
       getgroupstats,
       getauc,
       getlogloss,
       cache,
       CovariateStats,
       FactorStats,
       LevelStats,
       tryread,
       slice,
       nextslice,
       map

include("const.jl")
include("DataStructures/seq.jl")
include("DataStructures/list.jl")
include("DataStructures/tree.jl")
include("util.jl")
include("DataImport/dataimport.jl")
include("DataFrame/dataframe.jl")
include("DataFrame/groupstats.jl")

include("Covariates/groupstatscovariate.jl")

include("Factors/factor.jl")
include("Factors/constfactor.jl")
include("Factors/filefactor.jl")
include("Factors/ordinalfactor.jl")
include("Factors/cachedfactor.jl")
include("Factors/filecachedfactor.jl")
include("Factors/bincovfactor.jl")
include("Factors/boolvarfactor.jl")
include("Factors/maplevelfactor.jl")
include("Factors/permutefactor.jl")
include("Factors/widerfactor.jl")
include("Factors/bindatetimefactor.jl")

include("IntVariates/intvariate.jl")
include("IntVariates/fileintvariate.jl")

include("Covariates/covariate.jl")
include("Covariates/constcovariate.jl")
include("Covariates/filecovariate.jl")
include("Covariates/cachedcovariate.jl")
include("Covariates/filecachedcovariate.jl")
include("Covariates/transcovariate.jl")
include("Covariates/trans2covariate.jl")
include("Covariates/parsefactorcovariate.jl")
include("Covariates/ifelsecovariate.jl")
include("Covariates/unixdatecovariate.jl")
include("Covariates/transdatetimecovariate.jl")
include("Covariates/randcovariate.jl")


include("BoolVariates/boolvariate.jl")
include("BoolVariates/cachedboolvariate.jl")
include("BoolVariates/filecachedboolvariate.jl")
include("BoolVariates/transboolvariate.jl")
include("BoolVariates/trans2boolvariate.jl")
include("BoolVariates/transcovboolvariate.jl")
include("BoolVariates/trans2covboolvariate.jl")
include("BoolVariates/transdatetimeboolvariate.jl")
include("BoolVariates/trans2datetimeboolvariate.jl") 
include("BoolVariates/groupstatsboolvariate.jl")

include("DateTimeVariates/datetimevariate.jl")
include("DateTimeVariates/filedatetimevariate.jl")
include("DateTimeVariates/transdatetimevariate.jl")
include("DateTimeVariates/trans2datetimevariate.jl")

include("XGBoost/tree.jl")
include("XGBoost/split.jl")
include("XGBoost/logistic.jl")

end