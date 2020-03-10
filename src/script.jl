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

fannie_df = DataFrame("D:\\FannieMae\\Performance_All\\Performance_2017Q4"; preload = true)

@time s = summary(fannie_df[:servicer_name])

@time s = summary(factor(fannie_df[:loan_age]))
@time f = factor(fannie_df[:loan_age])
@time summary(f)
