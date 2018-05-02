push!(LOAD_PATH, "C:\\Users\\adamm\\Dropbox\\Development\\JuML\\src")
#push!(LOAD_PATH, "C:\\Users\\statfactory\\Documents\\JuML.jl\\src")
using JuML

@time importcsv("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\train_sample.csv";
                 isnumeric = (colname, levelfreq) -> colname in ["is_attributed"],
                 isdatetime = (colname, levelfreq) -> colname in ["click_time", "attributed_time"] ? (true, "y-m-d H:M:S") : (false, ""))

@time importcsv("C:\\Users\\adamm\\Documents\\Julia\\kaggle\\train.csv";
                 isnumeric = (colname, levelfreq) -> colname in ["is_attributed"],
                 isinteger = (colname, levelfreq) -> colname in ["ip"],
                 isdatetime = (colname, levelfreq) -> colname in ["click_time", "attributed_time"] ? (true, "y-m-d H:M:S") : (false, ""))

@time importcsv("C:\\Users\\adamm\\Documents\\Julia\\kaggle\\test.csv";
                 isnumeric = (colname, levelfreq) -> false,
                 isinteger = (colname, levelfreq) -> colname in ["ip", "click_id"],
                 isdatetime = (colname, levelfreq) -> colname in ["click_time"] ? (true, "y-m-d H:M:S") : (false, ""))

@time importcsv("C:\\Users\\adamm\\Documents\\Julia\\kaggle\\train.csv"; path2 = "C:\\Users\\adamm\\Documents\\Julia\\kaggle\\test.csv",
                 isnumeric = (colname, levelfreq) -> colname in ["is_attributed"],
                 isinteger = (colname, levelfreq) -> colname in ["ip", "click_id"],
                 isdatetime = (colname, levelfreq) -> colname in ["click_time", "attributed_time"] ? (true, "y-m-d H:M:S") : (false, ""))

@time importcsv("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\train.csv"; path2 = "C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\testsup.csv",
                 isnumeric = (colname, levelfreq) -> colname in ["is_attributed"],
                 isinteger = (colname, levelfreq) -> colname in ["ip", "click_id"],
                 isdatetime = (colname, levelfreq) -> colname in ["click_time", "attributed_time"] ? (true, "y-m-d H:M:S") : (false, ""))


#train_df = DataFrame("C:\\Users\\adamm_000\\Documents\\Julia\\kaggle\\train", preload = false)
test_df = DataFrame("C:\\Users\\adamm\\Documents\\Julia\\kaggle\\test", preload = false)
traintest_df = DataFrame("C:\\Users\\adamm_000\\Documents\\Julia\\kaggle\\traintestsup", preload = false)
#train_df = DataFrame("C:\\Users\\adamm\\Documents\\Julia\\kaggle\\train", preload = false)

#n = length(traintest_df) - length(test_df)
#train_df = filter(BoolVariate("train", BitArray((1:length(traintest_df)) .<= n)), traintest_df)

label = traintest_df["is_attributed"] 
click_time = traintest_df["click_time"]
#summary(click_time)

#clickday = factor(JuML.TransDateTimeCovariate("ClickDay", click_time, Dates.dayofweek));
#clickhour = factor(JuML.TransDateTimeCovariate("ClickHour", click_time, Dates.hour));
nmin = 60
clickhour = factor(JuML.TransDateTimeCovariate("ClickHour", click_time, dt -> (24 * 60 * Dates.dayofweek(dt) + 60 * Dates.hour(dt) + Dates.minute(dt)) ÷ nmin)) |> cache;
#clickminute = factor(JuML.TransDateTimeCovariate("ClickMinute", click_time, dt -> 24 * 60 * Dates.dayofweek(dt) + 60 * Dates.hour(dt) + Dates.minute(dt))) |> cache
#clicksec = factor(click_time);
#summary(clickhour)



function maplevels(f::JuML.AbstractFactor, minfreq::Integer)
    levels = Set(map((x -> x.level), filter((x -> x.freq >= minfreq), JuML.getstats(f).levelstats)))
    JuML.MapLevelFactor(JuML.getname(f), f, level -> level in levels ? level : "Other")
end

#p1 = DateTime(2017, 11, 10, 4, 0, 0), DateTime(2017, 11, 10, 6, 0, 0)
#p2 = DateTime(2017, 11, 10, 9, 0, 0), DateTime(2017, 11, 10, 11, 0, 0)
#p3 = DateTime(2017, 11, 10, 13, 0, 0), DateTime(2017, 11, 10, 15, 0, 0)

#teststart = DateTime(2017, 11, 9, 16, 0, 0)
validstart = DateTime(2017, 11, 9, 13, 0, 0)
haslabel = JuML.TransCovBoolVariate("", label, x -> !isnan(x))

trainset = JuML.TransDateTimeBoolVariate("", click_time, t -> t < validstart) 
validset = JuML.TransDateTimeBoolVariate("", click_time, t -> t >= validstart) .& haslabel

#trainset = BoolVariate("", BitArray(x <= 57000000 for x in 1:60000000))
#validset = BoolVariate("", BitArray(x > 57000000 for x in 1:60000000))

#zeroset = BoolVariate("", BitArray{1}(0))
#testset = JuML.TransDateTimeBoolVariate("", click_time, t -> t == p1[2]) 
#summary(testset)
#trainvalidset = or.(trainset, validset)
#allset = or.(trainvalidset, testset) |> cache

#r = rand(Float32, length(label))
#trainset = BoolVariate("", r .<= 0.95) .& haslabel
#validset = BoolVariate("", r .> 0.95) .& haslabel
#allset = or.(haslabel, testset) |> cache
#allcount = count(convert(BitArray{1}, allset))

#r = Vector{Float32}()

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

#hourcount = JuML.GroupStatsCovariate("hourcount", getgroupstats(clickhour24)) |> cache
#ipdevicehourpcnt = JuML.GroupStatsCovariate("iphourpcnt", getgroupstats(app, clickhour24)) ./ hourcount


#hourcount = JuML.GroupStatsCovariate("hourcount", getgroupstats(clickhour));

#minutecount = JuML.GroupStatsCovariate("minutecount", getgroupstats(clickminute));

#seccount = JuML.GroupStatsCovariate("minutecount", getgroupstats(clicksec));

#ip per hour:
iphourdaycount = JuML.GroupStatsCovariate("iphourdaycount", getgroupstats(ip, clickhour));
iphourappcount = JuML.GroupStatsCovariate("iphourappcount", getgroupstats(ip, clickhour, app));
iphouroscount = JuML.GroupStatsCovariate("iphouroscount", getgroupstats(ip, clickhour, os));
iphourdevicecount = JuML.GroupStatsCovariate("iphourdevicecount", getgroupstats(ip, clickhour, device));
iphourchannelcount = JuML.GroupStatsCovariate("iphourchannelcount", getgroupstats(ip, clickhour, channel));
iphourappchannelcount = JuML.GroupStatsCovariate("iphourappchannelcount", getgroupstats(ip, clickhour, app, channel));

#1way:
ipcount = JuML.GroupStatsCovariate("ipcount", getgroupstats(ip));
appcount = JuML.GroupStatsCovariate("appcount", getgroupstats(app));
oscount = JuML.GroupStatsCovariate("oscount", getgroupstats(os));
devicecount = JuML.GroupStatsCovariate("devicecount", getgroupstats(device));
channelcount = JuML.GroupStatsCovariate("channelcount", getgroupstats(channel));

#1way/hour:
iphourcount = JuML.GroupStatsCovariate("iphourcount", getgroupstats(ip, clickhour24));
apphourcount = JuML.GroupStatsCovariate("apphourcount", getgroupstats(app, clickhour24));
oshourcount = JuML.GroupStatsCovariate("oshourcount", getgroupstats(os, clickhour24));
devicehourcount = JuML.GroupStatsCovariate("devicehourcount", getgroupstats(device, clickhour24));
channelhourcount = JuML.GroupStatsCovariate("channelhourcount", getgroupstats(channel, clickhour24));

#2way:
ipappcount = JuML.GroupStatsCovariate("ipappcount", getgroupstats(ip, app));
ipdevicecount = JuML.GroupStatsCovariate("ipdevicecount", getgroupstats(ip, device));
iposcount = JuML.GroupStatsCovariate("iposcount", getgroupstats(ip, os));
ipchannelcount = JuML.GroupStatsCovariate("ipchannelcount", getgroupstats(ip, channel));
appdevicecount = JuML.GroupStatsCovariate("appdevicecount", getgroupstats(app, device));
apposcount = JuML.GroupStatsCovariate("apposcount", getgroupstats(app, os));
appchannelcount = JuML.GroupStatsCovariate("appchannelcount", getgroupstats(app, channel));
deviceoscount = JuML.GroupStatsCovariate("deviceoscount", getgroupstats(device, os));
devicechannelcount = JuML.GroupStatsCovariate("devicechannelcount", getgroupstats(device, channel));
oschannelcount = JuML.GroupStatsCovariate("oschannelcount", getgroupstats(os, channel));

#3way:
deviceoschannelcount = JuML.GroupStatsCovariate("ipappcount", getgroupstats(device, os, channel));
apposchannelcount = JuML.GroupStatsCovariate("ipdevicecount", getgroupstats(app, os, channel));
deviceappchannelcount = JuML.GroupStatsCovariate("iposcount", getgroupstats(device, app, channel));
deviceapposcount = JuML.GroupStatsCovariate("ipchannelcount", getgroupstats(device, app, os));
iposchannelcount = JuML.GroupStatsCovariate("appdevicecount", getgroupstats(ip, os, channel));
ipdevicechannelcount = JuML.GroupStatsCovariate("apposcount", getgroupstats(ip, device, channel));
iposdevicecount = JuML.GroupStatsCovariate("appchannelcount", getgroupstats(ip, os, device));
ipappchannelcount = JuML.GroupStatsCovariate("deviceoscount", getgroupstats(ip, app, channel));
ipapposcount = JuML.GroupStatsCovariate("devicechannelcount", getgroupstats(ip, app, os));
ipappdevicecount = JuML.GroupStatsCovariate("oschannelcount", getgroupstats(ip, app, device));




oshourcount = JuML.GroupStatsCovariate("oshourcount", getgroupstats(os, clickhour));
apphourcount = JuML.GroupStatsCovariate("apphourcount", getgroupstats(app, clickhour));
channelhourcount = JuML.GroupStatsCovariate("channelhourcount", getgroupstats(channel, clickhour));
devicehourcount = JuML.GroupStatsCovariate("devicehourcount", getgroupstats(device, clickhour));
#ipapposcount = JuML.GroupStatsCovariate("ipapposcount", getgroupstats((ip, app, os)))

# hourcount = JuML.GroupStatsCovariate("hourcount", getgroupstats(clickhour))
# iphourcount = JuML.GroupStatsCovariate("iphourcount", getgroupstats((ip, clickhour)))
# ipappcount = JuML.GroupStatsCovariate("ipappcount", getgroupstats((ip, app)))
# ipdevicecount = JuML.GroupStatsCovariate("ipdevicecount", getgroupstats((ip, device)))



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
onewayfactors = map((cov -> JuML.factor(cov)), [hourcount, ipcount, oscount, devicecount, appcount, channelcount])
#poswgt = (1.0 - labelstats.mean) / labelstats.mean
#datafactors = [clickhour24, JuML.OrdinalFactor(os), JuML.OrdinalFactor(device), JuML.OrdinalFactor(app,), JuML.OrdinalFactor(channel)]

iphourfactors = map((cov -> JuML.factor(cov)), [iphourdaycount, iphouroscount, iphourdevicecount, iphourappcount, iphourchannelcount, iphourappchannelcount])
#onewayhourfactors = map((cov -> JuML.factor(cov)), [hourcount, iphourcount, oshourcount, devicehourcount, apphourcount, channelhourcount])

twowayfactors = map((cov -> JuML.factor(cov)), [ipappcount, ipdevicecount, ipchannelcount, iposcount, appdevicecount, apposcount, appchannelcount, deviceoscount, devicechannelcount, oschannelcount])

#threewayfactors = map((cov -> JuML.factor(cov)), [deviceoschannelcount, apposchannelcount, deviceappchannelcount, deviceapposcount, iposchannelcount, ipdevicechannelcount, iposdevicecount, ipappchannelcount, ipapposcount, ipappdevicecount])

labelstats = getstats(label)

poswgt = (1.0 - labelstats.mean) * 100.0

mapped = map((f -> maplevels(f, 10000)), [app, device, channel, os])

@time model = xgblogit(label, [iphourfactors; mapped]; trainselector = trainset, validselector = validset, η = 0.1, λ = 1.0, γ = 0.0, μ = 0.5, subsample = 1.0, posweight = poswgt, minchildweight = 0.0, nrounds = 150, maxdepth = 7, ordstumps = true, pruning = false, leafwise = false, maxleaves = 8, caching = true, usefloat64 = false, singlethread = false, slicelength = 1000000);

#@time testpred = predict(model, test_df; posweight = poswgt)

testlen = length(test_df["click_id"])
is_attr = Covariate("is_attributed", model.pred[(length(traintest_df) - testlen + 1):end])

click_id = test_df["click_id"]
sub_df = DataFrame(testlen, JuML.AbstractFactor[], [is_attr], JuML.AbstractBoolVariate[], JuML.AbstractDateTimeVariate[], [click_id], "")
JuML.tocsv("C:\\Users\\adamm\\Documents\\Julia\\kaggle\\submission.csv", sub_df)














