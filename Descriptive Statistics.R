library(compareGroups)

library(savvy)
setwd("/work/ctheis")

query <- (
  " select *
    from udb_ctheis..cat_Final_Analysis_Set
    where Begin_Yr in (2012,2013)
      ")

FullData <- read.odbc("Devsql10dsn", NULL, query)

FullData$HDHP_Yr2_Flag <- as.factor(FullData$HDHP_Yr2_Flag)
FullData$NoChoice_Flag <- as.factor(FullData$NoChoice_Flag)
FullData$PostYearFlag <- as.factor(FullData$PostYearFlag)
FullData$Annual_IOP_Allow_Amount <- FullData$Annual_IP_Allow_Amount+FullData$Annual_OP_Allow_Amount

save(FullData,file="/work/ctheis/CDHC/FullData.RData")

str(FullData)

#look 
PreYear <- subset(FullData, (PreYearFlag == 1))
PostYear <- subset(FullData, (PreYearFlag == 0))

summary(PreYear)
summary(PostYear)

PreYearResults <- compareGroups(PlanYear2OfferAndChoice ~  Age + Gdr_Cd + RAF + OfficeVisitCopay + IndividualDeductible + IndividualOOP
                        + Annual_Allow_Amount + Annual_IOP_Allow_Amount 
                        + Annual_Dr_Allow_Amount  + Annual_Rx_Allow_Amount, data=PreYear)
createTable(PreYearResults)

PostYearResults <- compareGroups(PlanYear2OfferAndChoice ~  Age + Gdr_Cd + RAF + OfficeVisitCopay + IndividualDeductible + IndividualOOP
                        + Annual_Allow_Amount + Annual_IOP_Allow_Amount 
                        + Annual_Dr_Allow_Amount  + Annual_Rx_Allow_Amount, data=PostYear)
createTable(PostYearResults)



#this blocks sets theme parameters around background and gridlines
ss_theme <- theme_bw() + 
  theme(panel.border=element_blank(), axis.line=element_line("#a6a6a6")) + 
  theme(panel.grid.major.y = element_line("dashed", size = .5, colour="#a6a6a6"),  
        panel.grid.minor.y = element_line("dashed", size = .5, colour="#a6a6a6"),  
        panel.grid.major.x = element_line(size = .5, colour="#a6a6a6")) 

#create box-whisker plots for allowed amount
# compute lower and upper whiskers --used to eliminate extreme outliers in display
ylim1 = boxplot.stats(FullData$Annual_Allow_Amount)$stats[c(1, 5)]

#create chart
ggplot(data=FullData, aes(x=factor(PlanYear2OfferAndChoice), 
                          fill=factor(PostYearFlag), 
                          y=Annual_Allow_Amount, 
                          ymax=max(ylim1)*1))+ #ymax prevents error message nothing else
  geom_boxplot()+
  coord_cartesian(ylim = ylim1*1)  +
  stat_summary(fun.y="mean", geom="point", shape=5, size=5, position=position_dodge(width=0.75)) +
  scale_fill_manual(values = c("#4f81bd", "#febe01")) +
  ggtitle("Allowed Amount by Option and Plan")+
  xlab("Plan Options and Year 2 Plan") +
  ylab("Annual Allowed Amount") + 
  labs(fill="Post-year Flag")+
  ss_theme

#create box-whisker plots for physician allowed amount
# compute lower and upper whiskers --used to eliminate extreme outliers in display
ylim1 = boxplot.stats(FullData$Annual_Dr_Allow_Amount)$stats[c(1, 5)]

#create allowed amount
ggplot(data=FullData, aes(x=factor(PlanYear2OfferAndChoice), 
                          fill=factor(PostYearFlag), 
                          y=Annual_Dr_Allow_Amount, 
                          ymax=max(ylim1)*1.1))+ #ymax prevents error message nothing else
  geom_boxplot() +
  coord_cartesian(ylim = ylim1*1.1)  +
  stat_summary(fun.y="mean", geom="point", shape=5, size=5, position=position_dodge(width=0.75)) +
  scale_fill_manual(values = c("#4f81bd", "#febe01")) +
  ggtitle("Physician Allowed Amount by Option and Plan")+
  xlab("Plan Options and Year 2 Plan") +
  ylab("Annual Physician Allowed Amount") + 
  labs(fill="Post-year Flag")+
  ss_theme

#create box-whisker plots for pharmacy allowed amount
# compute lower and upper whiskers --used to eliminate extreme outliers in display
ylim1 = boxplot.stats(FullData$Annual_Rx_Allow_Amount)$stats[c(1, 5)]

#create allowed amount
ggplot(data=FullData, aes(x=factor(PlanYear2OfferAndChoice), 
                          fill=factor(PostYearFlag), 
                          y=Annual_Rx_Allow_Amount, 
                          ymax=max(ylim1)*1.1))+ #ymax prevents error message nothing else
  geom_boxplot() +
  coord_cartesian(ylim = ylim1*1.1)  +
  stat_summary(fun.y="mean", geom="point", shape=5, size=5, position=position_dodge(width=0.75)) +
  scale_fill_manual(values = c("#4f81bd", "#febe01")) +
  ggtitle("Prescription Drug Allowed Amount by Choice and Plan")+
  xlab("Plan Options and Year 2 Plan") +
  ylab("Annual Prescription Drug Allowed Amount") + 
  labs(fill="Post-year Flag")+
  ss_theme

#create box-whisker plots for pharmacy allowed amount
# compute lower and upper whiskers --used to eliminate extreme outliers in display
ylim1 = boxplot.stats(FullData$Annual_IOP_Allow_Amount)$stats[c(1, 5)]

#create allowed amount
ggplot(data=FullData, aes(x=factor(PlanYear2OfferAndChoice), 
                          fill=factor(PostYearFlag), 
                          y=Annual_IOP_Allow_Amount, 
                          ymax=max(ylim1)*1.1))+ #ymax prevents error message nothing else
  geom_boxplot() +
  coord_cartesian(ylim = ylim1*1.1)  +
  stat_summary(fun.y="mean", geom="point", shape=5, size=5, position=position_dodge(width=0.75)) +
  scale_fill_manual(values = c("#4f81bd", "#febe01")) +
  ggtitle("Inpatient & Outpatient Allowed Amount by Choice and Plan")+
  xlab("Plan Options and Year 2 Plan") +
  ylab("Annual Inpatient & Outpatient Allowed Amount") + 
  labs(fill="Post-year Flag")+
  ss_theme

#other charts not used
library(plyr)
coefs <- ddply(mtcars, .(cyl), function(df) {
  m <- lm(mpg ~ wt, data=df)
  data.frame(a = coef(m)[1], b = coef(m)[2])
})
str(coefs)

AllowRAF <- lm(data=FullData, Annual_Allow_Amount~RAF)

ggplot(data=FullData, aes(y=Annual_Allow_Amount, x=RAF)) +
  geom_point(colour = "#febe01")+
  stat_smooth(method="lm", se=FALSE)+
  ss_theme

ggplot(data=FullData, aes(y=Annual_Allow_Amount, x=IndividualOOP)) +
  geom_point(colour = "#febe01")+
  stat_smooth(method="lm", se=FALSE)+
  ss_theme

Female <- subset(FullData, (Gdr_Cd=="F"))

ggplot(data=Female, aes(y=Annual_Allow_Amount, x=Age)) +
  geom_point(colour = "#febe01")+
  stat_smooth(method="lm", se=FALSE)+
  ss_theme

Male <- subset(FullData, (Gdr_Cd=="M"))

ggplot(data=Male, aes(y=Annual_Allow_Amount, x=Age)) +
  geom_point(colour = "#febe01")+
  stat_smooth(method="lm", se=FALSE)+
  ss_theme

summary(AllowRAF)


ggplot(data=FullData, aes(x=IndividualOOP)) +
  geom_histogram(colour = "#febe01")+
  ss_theme

ggplot(data=FullData, aes(x=log(IndividualOOP+1))) +
  geom_histogram(colour = "#febe01")+
  ss_theme