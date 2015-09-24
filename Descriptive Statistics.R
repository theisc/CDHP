library(compareGroups)

library(savvy)
setwd("/work/ctheis")

query <- (
  " select *
    from udb_ctheis..cat_Final_Analysis_Set
    where Begin_Yr in (2012,2013)
      ")

FullData <- read.odbc("Devsql10dsn", NULL, query)

FullData$PlanYear2Offer <- as.character(FullData$PlanYear2OfferAndChoice)

FullData$Grouper <- paste(substr(FullData$PlanYear2Offer,0,4),FullData$Year2HDHP_Flag)

PreYear <- subset(FullData, (PreYearFlag == 1))
PostYear <- subset(FullData, (PreYearFlag == 0))

str(FullData)

summary(PreYear)
summary(PostYear)

PreYearResults <- compareGroups(Grouper ~  Age + Gdr_Cd + RAF + OfficeVisitCopay + IndividualDeductible + IndividualOOP
                        + Annual_Allow_Amount + Annual_IP_Allow_Amount 
                        + Annual_OP_Allow_Amount + Annual_Dr_Allow_Amount  + Annual_Rx_Allow_Amount, data=PreYear)
createTable(PreYearResults)

PostYearResults <- compareGroups(Grouper ~  Age + Gdr_Cd + RAF + OfficeVisitCopay + IndividualDeductible + IndividualOOP
                        + Annual_Allow_Amount + Annual_IP_Allow_Amount 
                        + Annual_OP_Allow_Amount + Annual_Dr_Allow_Amount  + Annual_Rx_Allow_Amount, data=PostYear)
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
ggplot(data=FullData, aes(x=factor(Grouper,labels=c("Both-LD","Both-HD","HD-HD","LD-LD")), 
                          fill=factor(PostYearFlag), 
                          y=Annual_Allow_Amount, 
                          ymax=max(ylim1)*1.05))+ #ymax prevents error message nothing else
  geom_boxplot()+
  coord_cartesian(ylim = ylim1*1.05)  +
  stat_summary(fun.y="mean", geom="point", shape=5, size=5, position=position_dodge(width=0.75)) +
  scale_fill_manual(values = c("#4f81bd", "#febe01")) +
  ggtitle("Allowed Amount by Plan Type Offerings")+
  xlab("Year 2 Employer Plan Offerings and Employee Choice") +
  ylab("Annual Allowed Amount") + 
  labs(fill="Post-year Flag")+
  ss_theme

#create box-whisker plots for physician allowed amount
# compute lower and upper whiskers --used to eliminate extreme outliers in display
ylim1 = boxplot.stats(FullData$Annual_Dr_Allow_Amount)$stats[c(1, 5)]

#create allowed amount
ggplot(data=FullData, aes(x=factor(Grouper,labels=c("Both-LD","Both-HD","HD-HD","LD-LD")), 
                          fill=factor(PostYearFlag), 
                          y=Annual_Dr_Allow_Amount, 
                          ymax=max(ylim1)*1.05))+ #ymax prevents error message nothing else
  geom_boxplot()+
  coord_cartesian(ylim = ylim1*1.05)  +
  stat_summary(fun.y="mean", geom="point", shape=5, size=5, position=position_dodge(width=0.75)) +
  scale_fill_manual(values = c("#4f81bd", "#febe01")) +
  ggtitle("Physician Allowed Amount by Plan Type Offerings")+
  xlab("Year 2 Employer Plan Offerings and Employee Choice") +
  ylab("Annual Physician Allowed Amount") + 
  labs(fill="Post-year Flag")+
  ss_theme

