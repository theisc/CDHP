library(savvy)
library(MASS)
library(faraway)
load("/work/ctheis/CDHC/FullData.RData")

#create log values of allow amounts
FullData$Log_Annual_Allow_Amount    <- log(FullData$Annual_Allow_Amount+1)
FullData$Log_Annual_IP_Allow_Amount <- log(FullData$Annual_IP_Allow_Amount+1)
FullData$Log_Annual_OP_Allow_Amount <- log(FullData$Annual_OP_Allow_Amount+1)
FullData$Log_Annual_Dr_Allow_Amount <- log(FullData$Annual_Dr_Allow_Amount+1)
FullData$Log_Annual_Rx_Allow_Amount <- log(FullData$Annual_Rx_Allow_Amount+1)
FullData$Log_Annual_IOP_Allow_Amount <- log(FullData$Annual_IP_Allow_Amount+FullData$Annual_OP_Allow_Amount+1)


#create a diagnostic data set for testing basic model
DiagnosticData <- subset(FullData, (PreYearFlag==1))
DiagnosticData <- subset(FullData, (Annual_Allow_Amount<50000))
DiagnosticData <- DiagnosticData[sample(1:nrow(DiagnosticData), 100000, replace=FALSE),]

ggplot(data=FullData,aes(Log_Annual_IP_Allow_Amount))+
  geom_histogram()+
  ss_theme

TotalLog <- glm(Log_Annual_Allow_Amount  ~  Age + Gdr_Cd + Age*Gdr_Cd + OfficeVisitCopay 
                + log(IndividualDeductible+1) + log(IndividualOOP+1) + RAF, data=DiagnosticData, family=gaussian)

TotalLM <- lm(Log_Annual_Allow_Amount  ~  Age + Gdr_Cd + Age*Gdr_Cd + OfficeVisitCopay 
                + log(IndividualDeductible+1) + log(IndividualOOP+1) + RAF, data=DiagnosticData)

summary(TotalLog)
summary(TotalLM)
plot(TotalLog)
plot(TotalLM)


#chek on covariance and variance inflation factor
cor(NoChoiceData$Annual_Allow_Amount,NoChoiceData$RAF)
cor(NoChoiceData$Annual_Allow_Amount,NoChoiceData$IndividualOOP)
cor(NoChoiceData$IndividualDeductible,NoChoiceData$IndividualOOP)

g <- model.matrix(OP)

vif(g)

#difference in difference models
Total2 <- lm(Log_Annual_Allow_Amount  ~  Age + Gdr_Cd + Gdr_Cd*Age + RAF + OfficeVisitCopay 
        + log(IndividualDeductible+1) + log(IndividualOOP+1)
        + PostYearFlag + HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag, data=FullData)

IP2 <- lm(Log_Annual_IP_Allow_Amount  ~  Age + Gdr_Cd + Gdr_Cd*Age + RAF + OfficeVisitCopay 
        + log(IndividualDeductible+1) + log(IndividualOOP+1)
        + PostYearFlag + HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag, data=FullData)

OP2 <- lm(Log_Annual_OP_Allow_Amount  ~  Age + Gdr_Cd + RAF + OfficeVisitCopay 
        + log(IndividualDeductible+1) + log(IndividualOOP+1)
        + PostYearFlag + HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag, data=FullData)

IOP2 <- lm(Log_Annual_IOP_Allow_Amount  ~  Age + Gdr_Cd + Gdr_Cd*Age + RAF + OfficeVisitCopay 
        + log(IndividualDeductible+1) + log(IndividualOOP+1)
        + PostYearFlag + HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag, data=FullData)

Dr2 <- lm(Log_Annual_Dr_Allow_Amount  ~  Age + Gdr_Cd + Gdr_Cd*Age + RAF + OfficeVisitCopay 
        + log(IndividualDeductible+1) + log(IndividualOOP+1)
        + PostYearFlag + HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag, data=FullData)

Rx2 <- lm(Log_Annual_Rx_Allow_Amount  ~  Age + Gdr_Cd + Gdr_Cd*Age + RAF + OfficeVisitCopay 
        + log(IndividualDeductible+1) + log(IndividualOOP+1)
        + PostYearFlag + HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag, data=FullData)


summary(Total2)
summary(IP2)
summary(OP2)
summary(IOP2)
summary(Dr2)
summary(Rx2)

#difference in difference in difference models

Total3 <- lm(Log_Annual_Allow_Amount  ~  Age + Gdr_Cd + Gdr_Cd*Age + RAF + OfficeVisitCopay 
            + log(IndividualDeductible+1) + log(IndividualOOP+1)
            + NoChoice_Flag + NoChoice_Flag*PostYearFlag 
            + NoChoice_Flag*HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag*NoChoice_Flag
            + PostYearFlag + HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag, data=FullData)

IP3 <- lm(Log_Annual_IP_Allow_Amount  ~  Age + Gdr_Cd + Gdr_Cd*Age + RAF + OfficeVisitCopay 
         + log(IndividualDeductible+1) + log(IndividualOOP+1)
         + NoChoice_Flag + NoChoice_Flag*PostYearFlag 
         + NoChoice_Flag*HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag*NoChoice_Flag
         + PostYearFlag + HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag, data=FullData)

OP3 <- lm(Log_Annual_OP_Allow_Amount  ~  Age + Gdr_Cd + Gdr_Cd*Age + RAF + OfficeVisitCopay 
         + log(IndividualDeductible+1) + log(IndividualOOP+1)
         + NoChoice_Flag + NoChoice_Flag*PostYearFlag 
         + NoChoice_Flag*HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag*NoChoice_Flag
         + PostYearFlag + HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag, data=FullData)

IOP3 <- lm(Log_Annual_IOP_Allow_Amount  ~  Age + Gdr_Cd + Gdr_Cd*Age + RAF + OfficeVisitCopay 
         + log(IndividualDeductible+1) + log(IndividualOOP+1)
         + NoChoice_Flag + NoChoice_Flag*PostYearFlag 
         + NoChoice_Flag*HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag*NoChoice_Flag
         + PostYearFlag + HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag, data=FullData)

Dr3 <- lm(Log_Annual_Dr_Allow_Amount  ~  Age + Gdr_Cd + Gdr_Cd*Age + RAF + OfficeVisitCopay 
         + log(IndividualDeductible+1) + log(IndividualOOP+1)
         + NoChoice_Flag + NoChoice_Flag*PostYearFlag 
         + NoChoice_Flag*HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag*NoChoice_Flag
         + PostYearFlag + HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag, data=FullData)


Rx3 <- lm(Log_Annual_Rx_Allow_Amount  ~  Age + Gdr_Cd + Gdr_Cd*Age + RAF + OfficeVisitCopay 
         + log(IndividualDeductible+1) + log(IndividualOOP+1)
         + NoChoice_Flag + NoChoice_Flag*PostYearFlag 
         + NoChoice_Flag*HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag*NoChoice_Flag
         + PostYearFlag + HDHP_Yr2_Flag + PostYearFlag*HDHP_Yr2_Flag, data=FullData)


summary(Total3)
summary(IP3)
summary(OP3)
summary(IOP3)
summary(Dr3)
summary(Rx3)


