using JuML

@time importcsv("C:\\Users\\adamm_000\\Documents\\Julia\\test_categorical.csv", 100000, 10000)

headerPath = "C:\\Users\\adamm_000\\Documents\\Julia\\test_categorical\\header.txt"

df = DataFrame(headerPath);

ff = df["L0_S1_F25"]
ss = summary(ff)
cc = df["Id"]
summary(cc)
















     
    

