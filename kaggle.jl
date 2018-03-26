#push!(LOAD_PATH, "C:\\Users\\adamm\\Dropbox\\Development\\JuML\\src")
push!(LOAD_PATH, "C:\\Users\\statfactory\\Documents\\JuML.jl\\src")
using JuML

@time importcsv("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\train_sample.csv";
                 isnumeric = (colname, levelfreq) -> colname in ["is_attributed"],
                 isdatetime = (colname, levelfreq) -> colname in ["click_time", "attributed_time"] ? (true, "y-m-d H:M:S") : (false, ""))

@time importcsv("C:\\Users\\adamm_000\\Documents\\Julia\\kaggle\\train.csv";
                 isnumeric = (colname, levelfreq) -> colname in ["is_attributed"],
                 isdatetime = (colname, levelfreq) -> colname in ["click_time", "attributed_time"] ? (true, "y-m-d H:M:S") : (false, ""))

@time importcsv("C:\\Users\\adamm_000\\Documents\\Julia\\kaggle\\test.csv";
                 isnumeric = (colname, levelfreq) -> false,
                 isdatetime = (colname, levelfreq) -> colname in ["click_time"] ? (true, "y-m-d H:M:S") : (false, ""))

train_df = DataFrame("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\train", preload = true)
test_df = DataFrame("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\test", preload = true)

factors = train_df.factors

label = train_df["is_attributed"]
click_time = train_df["click_time"]
summary(click_time)

day = JuML.TransDateTimeCovariate("ClickDay", click_time, Dates.dayofweek)
clickhour = factor(JuML.TransDateTimeCovariate("ClickDay", click_time, Dates.hour), 0:24)
summary(day)

# function prepfactor(factorname::String, train::DataFrame, test::DataFrame)
#     train_f = train[factorname]
#     test_f = test[factorname]
#     testset = Set(JuML.getlevels(test_f))
#     newfactor = MapLevelFactor(factorname, train_f, (level::String -> level in testset ? level : "NotInTest"))
#     JuML.OrdinalFactor(newfactor)
# end

function fmean(f::JuML.AbstractFactor, label::JuML.AbstractCovariate, labelstats, gstats)
    #gstats = JuML.getstats([f], label)
    m = JuML.GroupStatsCovariate(JuML.getname(f), gstats, s -> isnan(s.mean) ? labelstats.mean : s.mean)
    JuML.factor(m, 0.0:0.004:1.0)
end

function fcount(f::JuML.AbstractFactor, label::JuML.AbstractCovariate, gstats)
    #gstats = JuML.getstats([f], label)
    c = JuML.GroupStatsCovariate(JuML.getname(f), gstats, s -> s.obscount)
    s = getstats(c)
    mx = s.max
    step = mx / 250.0
    JuML.factor(c, 0.0:step:mx)
end

function maplevels(trainfactor::JuML.AbstractFactor, testfactor::JuML.AbstractFactor)
    testlevels = Set(JuML.getlevels(testfactor))
    JuML.MapLevelFactor(JuML.getname(trainfactor), trainfactor, level -> level in testlevels ? level : "NotInTest")
end

# ip = prepfactor("ip", train_df, test_df)
# os = prepfactor("os", train_df, test_df)
# channel = prepfactor("channel", train_df, test_df)
# device = prepfactor("device", train_df, test_df)
# app = prepfactor("app", train_df, test_df)


# r = rand(Float32, length(label))
# trainset = r .<= 0.9
# testset = r .> 0.9

#trainset = (day .< 4) |> JuML.cache
#testset = (day .== 4) |> JuML.cache

cutoff = DateTime(2017, 11, 9, 11, 0, 0)
trainset = JuML.TransDateTimeBoolVariate("", click_time, t -> t <= cutoff) |> JuML.cache;
#testset = JuML.TransDateTimeBoolVariate("", click_time, t -> t > cutoff) |> JuML.cache;
summary(trainset)

testip = test_df["ip"]
testos = test_df["os"]
testapp = test_df["app"]
testchannel = test_df["channel"]
testdevice = test_df["device"]

ip = maplevels(train_df["ip"], testip)
os = maplevels(train_df["os"], testos)
app = maplevels(train_df["app"], testapp)
channel = maplevels(train_df["channel"], testchannel)
device = maplevels(train_df["device"], testdevice)

ipgstats = JuML.getstats([ip], label)
osgstats = JuML.getstats([os], label)
appgstats = JuML.getstats([app], label)
channelgstats = JuML.getstats([channel], label)
devicegstats = JuML.getstats([device], label)

labelstats = getstats(label)



# pred = JuML.GroupStatsCovariate("", gstats, s -> s.mean)
# p = collect(convert(Vector{Float32}, pred))
# summary(pred)

# mpred = map(pred, test_df)

# auc = JuML.getauc(collect(convert(Vector{Float32}, pred)), label)
# f = factor(covtest, 0.0:0.1:1.0)
# summary(f)

function toordinal(factor::JuML.AbstractFactor)
    JuML.OrdinalFactor(JuML.getname(factor), factor, (x, y) -> parse(x) < parse(y)) 
end


modelfactors = [fmean(ip, label, labelstats, ipgstats), fcount(ip, label, ipgstats), fmean(os, label, labelstats, osgstats), fcount(os, label, osgstats), fmean(device, label, labelstats, devicegstats), fcount(device, label, devicegstats), fmean(channel, label, labelstats, channelgstats), fcount(channel, label, channelgstats), fmean(app, label, labelstats, appgstats), fcount(app, label, appgstats)]
@time model = xgblogit(label, modelfactors; selector = trainset, η = 0.3, λ = 1.0, γ = 0.0, μ = 0.5, subsample = 1.0, posweight = 1.0, minchildweight = 0.0, nrounds = 10, maxdepth = 1, ordstumps = true, pruning = false, leafwise = true, maxleaves = 10, caching = true, usefloat64 = true, singlethread = false, slicelength = 1000000);

@time trainauc = getauc(model.pred, label; selector = trainset)
@time testauc = getauc(model.pred, label; selector = testset)

mean(model.pred)
@time pred = predict(model, test_df)
mean(pred)
is_attr = Covariate("is_attributed", pred)
click_id = test_df["click_id"]
sub_df = DataFrame(length(pred), [click_id], [is_attr], JuML.AbstractBoolVariate[], JuML.AbstractDateTimeVariate[])
JuML.tocsv("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\submission.csv", sub_df)














