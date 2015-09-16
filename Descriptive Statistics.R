library(compareGroups)

library(savvy)
setwd("/work/ctheis")

query <- (
  " select *
    from udb_ctheis..cat_Final_Analysis_Set
    where Begin_Yr in (2012,2013)
      ")

FullData <- read.odbc("Devsql10dsn", NULL, query)

PreYear <- subset(FullData, (PreYearFlag == 1))
PostYear <- subset(FullData, (PreYearFlag == 0))
PostYearLDHP <- subset(PostYear, (HDHP_Flag == 0))
PostYearHDHP <- subset(PostYear, (HDHP_Flag == 1))


summary(PreYear)
summary(PostYear)

PreYearResults <- compareGroups(PlanTypesOffered ~  Age + Gdr_Cd + RAF + Annual_Allow_Amount + Annual_IP_Allow_Amount 
                         + Annual_OP_Allow_Amount + Annual_Dr_Allow_Amount  + Annual_Rx_Allow_Amount, data=PreYear)
createTable(PreYearResults)

PostYearResults <- compareGroups(PlanTypesOffered ~  Age + Gdr_Cd + RAF + Annual_Allow_Amount + Annual_IP_Allow_Amount 
                                + Annual_OP_Allow_Amount + Annual_Dr_Allow_Amount  + Annual_Rx_Allow_Amount, data=PostYear)
createTable(PostYearResults)

PostYearHDHPResults <- compareGroups(PlanTypesOffered ~  Age + Gdr_Cd + RAF + Annual_Allow_Amount + Annual_IP_Allow_Amount 
                                 + Annual_OP_Allow_Amount + Annual_Dr_Allow_Amount  + Annual_Rx_Allow_Amount, data=PostYearHDHP)
createTable(PostYearHDHPResults)

PostYearLDHPResults <- compareGroups(PlanTypesOffered ~  Age + Gdr_Cd + RAF + Annual_Allow_Amount + Annual_IP_Allow_Amount 
                                     + Annual_OP_Allow_Amount + Annual_Dr_Allow_Amount  + Annual_Rx_Allow_Amount, data=PostYearLDHP)
createTable(PostYearLDHPResults)