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

@time importcsv("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\train.csv"; path2 = "C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\test.csv",
                 isnumeric = (colname, levelfreq) -> colname in ["is_attributed"],
                 isdatetime = (colname, levelfreq) -> colname in ["click_time", "attributed_time"] ? (true, "y-m-d H:M:S") : (false, ""))

#train_df = DataFrame("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\train_sample", preload = false)
test_df = DataFrame("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\test", preload = false)
traintest_df = DataFrame("C:\\Users\\adamm_000\\Documents\\Julia\\kaggle\\traintest", preload = false)

factors = traintest_df.factors
label = traintest_df["is_attributed"] 
click_time = traintest_df["click_time"]
summary(click_time)

clickday = factor(JuML.TransDateTimeCovariate("ClickDay", click_time, Dates.day)) 
clickhour24 = factor(JuML.TransDateTimeCovariate("ClickHour24", click_time, Dates.hour)) 
clickhour = factor(JuML.TransDateTimeCovariate("ClickDay", click_time, dt -> 24 * Dates.dayofweek(dt) + Dates.hour(dt))) 
#clickminute = factor(JuML.TransDateTimeCovariate("ClickDay", click_time, dt -> 24 * 60 * Dates.dayofweek(dt) + 60 * Dates.hour(dt) + Dates.minute(dt)), 2312:6721)
#summary(clickhour)

# function prepfactor(factorname::String, train::DataFrame, test::DataFrame)
#     train_f = train[factorname]
#     test_f = test[factorname]
#     testset = Set(JuML.getlevels(test_f))
#     newfactor = MapLevelFactor(factorname, train_f, (level::String -> level in testset ? level : "NotInTest"))
#     JuML.OrdinalFactor(newfactor)
# end

# function fmean(f::JuML.AbstractFactor, label::JuML.AbstractCovariate, labelstats, gstats)
#     #gstats = JuML.getstats([f], label)
#     m = JuML.GroupStatsCovariate(JuML.getname(f), gstats, s -> isnan(s.mean) ? labelstats.mean : s.mean)
#     JuML.factor(m, 0.0:0.004:1.0)
# end

# function fcount(name::String, gstats)
#     c = JuML.GroupStatsCovariate(name, gstats, s -> s.obscount)
#     v = convert(Vector{Float32}, c)
#     JuML.factor(c, unique(v))
# end

# function maplevels(trainfactor::JuML.AbstractFactor, testfactor::JuML.AbstractFactor)
#     testlevels = Set(JuML.getlevels(testfactor))
#     JuML.MapLevelFactor(JuML.getname(trainfactor), trainfactor, level -> level in testlevels ? level : "NotInTest")
# end

# function quantilebin(cov::JuML.AbstractCovariate, qcount::Integer)
#     v = convert(Vector{Float32}, cov)
#     bins = unique(quantile(v, 0.0:(1.0 / qcount):1.0))
#     factor(cov, bins)
# end


# ip = prepfactor("ip", train_df, test_df)
# os = prepfactor("os", train_df, test_df)
# channel = prepfactor("channel", train_df, test_df)
# device = prepfactor("device", train_df, test_df)
# app = prepfactor("app", train_df, test_df)


r = rand(Float32, length(label))
trainset = BoolVariate("", r .<= 0.9) .& JuML.TransCovBoolVariate("", label, x -> !isnan(x)) 
validset = BoolVariate("", r .> 0.9) .& JuML.TransCovBoolVariate("", label, x -> !isnan(x)) 
r = Vector{Float32}()
# testset = r .> 0.9

#trainset = (day .< 4) |> JuML.cache
#testset = (day .== 4) |> JuML.cache

#cutoff = DateTime(2017, 11, 9, 11, 0, 0)
#trainset = JuML.TransDateTimeBoolVariate("", click_time, t -> t <= cutoff) |> JuML.cache;
#testset = JuML.TransDateTimeBoolVariate("", click_time, t -> t > cutoff) |> JuML.cache;
#summary(trainset)

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


ip = traintest_df["ip"] 
os = traintest_df["os"] 
app = traintest_df["app"] 
channel = traintest_df["channel"] 
device = traintest_df["device"] 


iphourcount = JuML.GroupStatsCovariate("iphourcount", getgroupstats(ip, clickhour)) 
oshourcount = JuML.GroupStatsCovariate("oshourcount", getgroupstats(os, clickhour))
apphourcount = JuML.GroupStatsCovariate("apphourcount", getgroupstats(app, clickhour)) 
channelhourcount = JuML.GroupStatsCovariate("channelhourcount", getgroupstats(channel, clickhour)) 
devicehourcount = JuML.GroupStatsCovariate("devicehourcount", getgroupstats(device, clickhour)) 
#ipapposcount = JuML.GroupStatsCovariate("ipapposcount", getgroupstats((ip, app, os)))

# hourcount = JuML.GroupStatsCovariate("hourcount", getgroupstats(clickhour))
# iphourcount = JuML.GroupStatsCovariate("iphourcount", getgroupstats((ip, clickhour)))
# ipappcount = JuML.GroupStatsCovariate("ipappcount", getgroupstats((ip, app)))
# ipdevicecount = JuML.GroupStatsCovariate("ipdevicecount", getgroupstats((ip, device)))

#labelstats = getstats(label)

#ipmean = JuML.GroupStatsCovariate("ipcount", getgroupstats(ip, label), s -> isnan(s.mean) ? labelstats.mean : s.mean)
#osmean = JuML.GroupStatsCovariate("oscount", getgroupstats(os, label), s -> isnan(s.mean) ? labelstats.mean : s.mean)
#appmean = JuML.GroupStatsCovariate("appcount", getgroupstats(app, label), s -> isnan(s.mean) ? labelstats.mean : s.mean)
#channelmean = JuML.GroupStatsCovariate("channelcount", getgroupstats(channel, label), s -> isnan(s.mean) ? labelstats.mean : s.mean)
#devicemean = JuML.GroupStatsCovariate("devicecount", getgroupstats(device, label), s -> isnan(s.mean) ? labelstats.mean : s.mean)
#hourmean = JuML.GroupStatsCovariate("hourcount", getgroupstats(clickhour, label), s -> isnan(s.mean) ? labelstats.mean : s.mean)
#iphourcount = JuML.GroupStatsCovariate("iphourcount", getgroupstats((ip, clickhour)))
#ipappcount = JuML.GroupStatsCovariate("ipappcount", getgroupstats((ip, app)))
#ipdevicecount = JuML.GroupStatsCovariate("ipdevicecount", getgroupstats((ip, device)))

# ipgstats = JuML.getstats([trainip], label)
# osgstats = JuML.getstats([trainos], label)
# appgstats = JuML.getstats([trainapp], label)
# channelgstats = JuML.getstats([trainchannel], label)
# devicegstats = JuML.getstats([traindevice], label)
# hourgstats = JuML.getstats([clickhour], label)

# daygstats = JuML.getstats([clickday], label)





# pred = JuML.GroupStatsCovariate("", gstats, s -> s.mean)
# p = collect(convert(Vector{Float32}, pred))
# summary(pred)

# mpred = map(pred, test_df)

# auc = JuML.getauc(collect(convert(Vector{Float32}, pred)), label)
# f = factor(covtest, 0.0:0.1:1.0)
# summary(f)

# function toordinal(factor::JuML.AbstractFactor)
#     JuML.OrdinalFactor(JuML.getname(factor), factor, (x, y) -> parse(x) < parse(y)) 
# end


#modelfactors = [clickday, clickhour, fmean(ip, label, labelstats, ipgstats), fcount(ip, label, ipgstats), fmean(os, label, labelstats, osgstats), fcount(os, label, osgstats), fmean(device, label, labelstats, devicegstats), fcount(device, label, devicegstats), fmean(channel, label, labelstats, channelgstats), fcount(channel, label, channelgstats), fmean(app, label, labelstats, appgstats), fcount(app, label, appgstats)]
#modelfactors = [fcount("hourstats", hourgstats), fcount("ipstats", ipgstats), fcount("osstats", osgstats), fcount("devicestats", devicegstats), fcount("channelstats", channelgstats), fcount("appstats", appgstats)]
#modelfactors = map((cov -> quantilebin(cov, 250)), [iphourcount, ipappcount, ipdevicecount, ipcount, oscount, devicecount, appcount, channelcount, hourcount])
modelfactors = map((cov -> JuML.factor(cov)), [iphourcount, oshourcount, devicehourcount, apphourcount, channelhourcount])
#poswgt = (1.0 - labelstats.mean) / labelstats.mean
datafactors = [clickhour24, clickday, JuML.OrdinalFactor(os), JuML.OrdinalFactor(device), JuML.OrdinalFactor(app,), JuML.OrdinalFactor(channel)]

@time model = xgblogit(label, [modelfactors; datafactors]; trainselector = trainset, validselector = validset, η = 0.1, λ = 1.0, γ = 0.0, μ = 0.5, subsample = 1.0, posweight = 100.0, minchildweight = 0.0, nrounds = 30, maxdepth = 11, ordstumps = true, pruning = false, leafwise = false, maxleaves = 32, caching = true, usefloat64 = false, singlethread = true, slicelength = 1000000);

#@time trainauc = getauc(model.pred, label; selector = trainset)
#@time testauc = getauc(model.pred, label; selector = testset)

#mean(model.pred)
#@time pred = predict(model, test_df)
#mean(pred)
testlen = length(test_df["click_id"])
is_attr = Covariate("is_attributed", model.pred[(length(model.pred) - testlen + 1):length(model.pred)])
click_id = test_df["click_id"]
sub_df = DataFrame(testlen, [click_id], [is_attr], JuML.AbstractBoolVariate[], JuML.AbstractDateTimeVariate[])
JuML.tocsv("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\submission.csv", sub_df)













