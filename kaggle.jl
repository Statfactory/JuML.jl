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

train_df = DataFrame("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\train", preload = false)
test_df = DataFrame("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\test", preload = false)

factors = train_df.factors
label = train_df["is_attributed"]
click_time = train_df["click_time"]
summary(click_time)

clickday = factor(JuML.TransDateTimeCovariate("ClickDay", click_time, Dates.dayofweek), 1:5)
clickhour = factor(JuML.TransDateTimeCovariate("ClickDay", click_time, dt -> 24 * Dates.dayofweek(dt) + Dates.hour(dt)), 38:113)
clickminute = factor(JuML.TransDateTimeCovariate("ClickDay", click_time, dt -> 24 * 60 * Dates.dayofweek(dt) + 60 * Dates.hour(dt) + Dates.minute(dt)), 2312:6721)
summary(clickhour)


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

function fcount(name::String, gstats)
    c = JuML.GroupStatsCovariate(name, gstats, s -> s.obscount)
    v = convert(Vector{Float32}, c)
    JuML.factor(c, unique(v))
end

function maplevels(trainfactor::JuML.AbstractFactor, testfactor::JuML.AbstractFactor)
    testlevels = Set(JuML.getlevels(testfactor))
    JuML.MapLevelFactor(JuML.getname(trainfactor), trainfactor, level -> level in testlevels ? level : "NotInTest")
end

function quantilebin(cov::JuML.AbstractCovariate, qcount::Integer)
    v = convert(Vector{Float32}, cov)
    bins = unique(quantile(v, 0.0:(1.0 / qcount):1.0))
    factor(cov, bins)
end


# ip = prepfactor("ip", train_df, test_df)
# os = prepfactor("os", train_df, test_df)
# channel = prepfactor("channel", train_df, test_df)
# device = prepfactor("device", train_df, test_df)
# app = prepfactor("app", train_df, test_df)


r = rand(Float32, length(label))
trainset = BoolVariate("", r .<= 0.9)
# testset = r .> 0.9

#trainset = (day .< 4) |> JuML.cache
#testset = (day .== 4) |> JuML.cache

cutoff = DateTime(2017, 11, 9, 11, 0, 0)
trainset = JuML.TransDateTimeBoolVariate("", click_time, t -> t <= cutoff) |> JuML.cache;
#testset = JuML.TransDateTimeBoolVariate("", click_time, t -> t > cutoff) |> JuML.cache;
summary(trainset)

# testip = test_df["ip"]
# testos = test_df["os"]
# testapp = test_df["app"]
# testchannel = test_df["channel"]
# testdevice = test_df["device"]

# ip = maplevels(train_df["ip"], testip)
# os = maplevels(train_df["os"], testos)
# app = maplevels(train_df["app"], testapp)
# channel = maplevels(train_df["channel"], testchannel)
# device = maplevels(train_df["device"], testdevice)

trainip = train_df["ip"]
trainos = train_df["os"]
trainapp = train_df["app"]
trainchannel = train_df["channel"]
traindevice = train_df["device"]

ipcount = JuML.GroupStatsCovariate("ipcount", JuML.getstats([trainip], label), s -> s.obscount)
oscount = JuML.GroupStatsCovariate("oscount", JuML.getstats([trainos], label), s -> s.obscount)
appcount = JuML.GroupStatsCovariate("appcount", JuML.getstats([trainapp], label), s -> s.obscount)
channelcount = JuML.GroupStatsCovariate("channelcount", JuML.getstats([trainchannel], label), s -> s.obscount)
devicecount = JuML.GroupStatsCovariate("devicecount", JuML.getstats([traindevice], label), s -> s.obscount)
hourcount = JuML.GroupStatsCovariate("hourcount", JuML.getstats([clickhour], label), s -> s.obscount)
iphourcount = JuML.GroupStatsCovariate("iphourcount", JuML.getstats([trainip, clickhour], label), s -> s.obscount)
ipappcount = JuML.GroupStatsCovariate("ipappcount", JuML.getstats([trainip, trainapp], label), s -> s.obscount)
ipdevicecount = JuML.GroupStatsCovariate("ipdevicecount", JuML.getstats([trainip, traindevice], label), s -> s.obscount)


# ipgstats = JuML.getstats([trainip], label)
# osgstats = JuML.getstats([trainos], label)
# appgstats = JuML.getstats([trainapp], label)
# channelgstats = JuML.getstats([trainchannel], label)
# devicegstats = JuML.getstats([traindevice], label)
# hourgstats = JuML.getstats([clickhour], label)

# daygstats = JuML.getstats([clickday], label)

# labelstats = getstats(label)



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


#modelfactors = [clickday, clickhour, fmean(ip, label, labelstats, ipgstats), fcount(ip, label, ipgstats), fmean(os, label, labelstats, osgstats), fcount(os, label, osgstats), fmean(device, label, labelstats, devicegstats), fcount(device, label, devicegstats), fmean(channel, label, labelstats, channelgstats), fcount(channel, label, channelgstats), fmean(app, label, labelstats, appgstats), fcount(app, label, appgstats)]
#modelfactors = [fcount("hourstats", hourgstats), fcount("ipstats", ipgstats), fcount("osstats", osgstats), fcount("devicestats", devicegstats), fcount("channelstats", channelgstats), fcount("appstats", appgstats)]
modelfactors = map((cov -> quantilebin(cov, 250)), [iphourcount, ipappcount, ipdevicecount, ipcount, oscount, devicecount, appcount, channelcount, hourcount])
@time model = xgblogit(label, modelfactors; selector = trainset, η = 0.1, λ = 1.0, γ = 0.0, μ = 0.5, subsample = 1.0, posweight = 1.0, minchildweight = 0.0, nrounds = 10, maxdepth = 6, ordstumps = true, pruning = false, leafwise = false, maxleaves = 32, caching = true, usefloat64 = false, singlethread = false, slicelength = 1000000);

@time trainauc = getauc(model.pred, label; selector = trainset)
@time testauc = getauc(model.pred, label; selector = testset)

mean(model.pred)
@time pred = predict(model, test_df)
mean(pred)
is_attr = Covariate("is_attributed", pred)
click_id = test_df["click_id"]
sub_df = DataFrame(length(pred), [click_id], [is_attr], JuML.AbstractBoolVariate[], JuML.AbstractDateTimeVariate[])
JuML.tocsv("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\submission.csv", sub_df)














