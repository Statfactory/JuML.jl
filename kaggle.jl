#push!(LOAD_PATH, "C:\\Users\\adamm\\Dropbox\\Development\\JuML\\src")
push!(LOAD_PATH, "C:\\Users\\statfactory\\Documents\\JuML.jl\\src")
using JuML

@time importcsv("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\train_sample.csv";
                 isnumeric = (colname, levelfreq) -> colname in ["is_attributed"],
                 isdatetime = (colname, levelfreq) -> colname in ["click_time", "attributed_time"] ? (true, "y-m-d H:M:S") : (false, ""))

@time importcsv("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\train.csv";
                 isnumeric = (colname, levelfreq) -> colname in ["is_attributed"],
                 isdatetime = (colname, levelfreq) -> colname in ["click_time", "attributed_time"] ? (true, "y-m-d H:M:S") : (false, ""))

@time importcsv("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\test.csv";
                 isnumeric = (colname, levelfreq) -> false,
                 isdatetime = (colname, levelfreq) -> colname in ["click_time"] ? (true, "y-m-d H:M:S") : (false, ""))

train_df = DataFrame("C:\\Users\\adamm_000\\Documents\\Julia\\kaggle\\train", preload = false)
test_df = DataFrame("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\test", preload = true)

factors = train_df.factors
label = train_df["is_attributed"]
click_time = train_df["click_time"]
summary(click_time)

day = JuML.TransDateTimeCovariate("ClickDay", click_time, Dates.dayofweek)
clickhour = factor(JuML.TransDateTimeCovariate("ClickDay", click_time, Dates.hour), 0:24)
summary(day)

# r = rand(Float32, length(label))
# trainset = r .<= 0.9
# testset = r .> 0.9

#trainset = (day .< 4) |> JuML.cache
#testset = (day .== 4) |> JuML.cache

cutoff = DateTime(2017, 11, 9, 8, 0, 0)
trainset = JuML.TransDateTimeBoolVariate("", click_time, t -> t <= cutoff) |> JuML.cache;
testset = JuML.TransDateTimeBoolVariate("", click_time, t -> t > cutoff) |> JuML.cache;

ip = train_df["ip"]

labelstats = getstats(label)

function toordinal(factor::JuML.AbstractFactor)
    JuML.OrdinalFactor(JuML.getname(factor), factor, (x, y) -> parse(x) < parse(y)) 
end

_, ipstats = getstats(ip, label);
iplevels = JuML.getlevels(ip)
d = Dict{String, String}()
for (i, level) in enumerate(iplevels)
    d[level] = string(ipstats[i].obscount)
end

mapiplevel = (level::String) -> begin
    get(d, level, ".")
end

iprate = JuML.MapLevelFactor("iprate", ip, mapiplevel)


_, hourstats = getstats(clickhour, label);
hourlevels = JuML.getlevels(clickhour)
d_hour = Dict{String, String}()
for (i, level) in enumerate(hourlevels)
    d_hour[level] = string(hourstats[i].mean)
end

maphourlevel = (level::String) -> begin
    get(d_hour, level, string(labelstats.mean))
end

hourrate = JuML.OrdinalFactor("", JuML.MapLevelFactor("hourrate", clickhour, maphourlevel), (x, y) -> parse(x) < parse(y))  

poswgt = 1.0
modelfactors = map(toordinal, [filter((f -> JuML.getname(f) != "ip"), factors); iprate])
@time model = xgblogit(label, modelfactors; selector = trainset, η = 0.1, λ = 1.0, γ = 0.0, μ = 0.5, subsample = 0.7, posweight = 1.0, minchildweight = 0.0, nrounds = 200, maxdepth = 5, ordstumps = true, pruning = true, caching = true, usefloat64 = false, singlethread = false, slicelength = 1000000);

@time trainauc = getauc(model.pred, label; selector = trainset)
@time testauc = getauc(model.pred, label; selector = testset)

mean(model.pred)
@time pred = predict(model, test_df; posweight = poswgt)
mean(pred)
is_attr = Covariate("is_attributed", pred)
click_id = test_df["click_id"]
sub_df = DataFrame(length(pred), [click_id], [is_attr], JuML.AbstractBoolVariate[], JuML.AbstractDateTimeVariate[])
JuML.tocsv("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\submission.csv", sub_df)











