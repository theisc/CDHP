
--create a set plan months that meet minimum criteria
if exists (select name from udb_ctheis.sys.objects where name = 'cat_Plan_Benefits')
drop table udb_ctheis..cat_Plan_Benefits

select 
	pm.Begin_Dt, 
	pm.PLN_BEN_SET_MDL_SYS_ID,
	lsm.FamilyDeductible,
	lsm.IndividualDeductible,
	lsm.FamilyOOP,
	lsm.IndividualOOP,
	Office_CostShareType	=	case when Office_CostShareType	is null then Urgent_CostShareType	else Office_CostShareType	end,
	Office_CostShareValue	=	case when Office_CostShareValue is null	then Urgent_CostShareValue	else Office_CostShareValue	end,
	--criteria based on https://en.wikipedia.org/wiki/High-deductible_health_plan
	HDHP_Flag	=	case 
					when year(pm.begin_dt) in (2011,2012) and IndividualDeductible >= 1200 and FamilyDeductible >= 2400	then 1
					when year(pm.begin_dt) in (2013,2014) and IndividualDeductible >= 1250 and FamilyDeductible >= 2500	then 1
					else 0
					end
into udb_ctheis..cat_Plan_Benefits
from udb_ctheis..Benefit_Set_Model_Plan_by_Month	pm
join udb_ctheis..Liability_Set_by_Month				lsm	on	lsm.PLN_BEN_SET_MDL_SYS_ID	=	pm.PLN_BEN_SET_MDL_SYS_ID
														and	lsm.Begin_DT				=	pm.Begin_DT
join udb_ctheis..Service_Event_Benefit_Set_by_Month	sem	on	sem.PLN_BEN_SET_MDL_SYS_ID	=	pm.PLN_BEN_SET_MDL_SYS_ID
														and	sem.Begin_DT				=	pm.Begin_DT
where (sem.Office_CostShareType	in (1,3) or sem.Urgent_CostShareType  in (1,3))  --has urgent care or office cost with per visit or coinsurance costs
	and IndividualDeductibleType	<>	2	-- exclued plans that have policy year deductibles and OOPs
	and IndividualOOPType			<>	2
	and FamilyDeductibleType		<>	2
	and FamilyOOPType				<>	2

create unique clustered index ix_plan_ben_set on udb_ctheis..cat_Plan_Benefits (PLN_BEN_SET_MDL_SYS_ID, Begin_DT)
--14974665 on 9/1/15

--create a table that has three 24 month periods 2011-2, 2012-3, 2013-4
select YEAR_NBR as Begin_Yr, Begin_DT
into #2year
from udb_ctheis..cat_AnalysisDates
where year_nbr < 2014
union
select YEAR_NBR-1, Begin_DT
from udb_ctheis..cat_AnalysisDates
where YEAR_NBR	> 2011


--for each customer segment and 2-year window need to know:
	--if they have benefit information for all of their plans for every month
	--when plans change if at all
	--if they have HDHP plan in year 2

--create table with these attributes for every customer and analysis period
if exists (select name from udb_ctheis.sys.objects where name = 'cat_Customer_by_Analysis_Period')
drop table udb_ctheis..cat_Customer_by_Analysis_Period

select 
	Cust_Seg_Sys_ID, 
	Begin_Yr,
	PlanTypesOffered	=	max(case 
								when Begin_Dt	<>	cast(cast(Begin_Yr+1 as char(4))+'0101' as date)	then null	--check first month of year 2 of analysis period
								when HDHP_Flag	=	1	and PlanTypeCount	=	2	then 'Both'						
								when HDHP_Flag	=	1	and PlanTypeCount	=	1	then 'HDHP'
								when HDHP_Flag	=	0	and PlanTypeCount	=	1	then 'LDHP'
								end),
	Year2HDHP			=	sum(case when year(Begin_Dt) = Begin_Yr+1 then HDHP_Flag end),							--count how many months HDHP are offered in year 2 of analysis period
	BothYearHDHP		=	sum(HDHP_Flag),																			--count how many months HDHP are offered in both years of analysis period
	PlanMonths			=	count(distinct begin_dt)																--count how many months we have any plan info for employer in both years of analysis period
into udb_ctheis..cat_Customer_by_Analysis_Period	
from (
	select
		sp.Cust_Seg_Sys_Id, sxb.begin_dt, Begin_Yr, 
		PlanCount		=	count(distinct sxb.PLN_BEN_SET_MDL_SYS_ID),
		BenePlanCount	=	count(distinct pb.PLN_BEN_SET_MDL_SYS_ID),
		PlanTypeCount	=	count(distinct pb.HDHP_Flag),															--1 if only low or high, 2 if both
		HDHP_Flag		=	max(HDHP_Flag)																			--if any plan in a month has a high deductible, this is counted
	from udb_ctheis..SavvyPlanID_to_BenSysID_by_Month	sxb
	left join udb_ctheis..cat_Plan_Benefits				pb	on	sxb.PLN_BEN_SET_MDL_SYS_ID	=	pb.PLN_BEN_SET_MDL_SYS_ID  --left join to see if there are more plans than those we have data for
															and	sxb.Begin_DT				=	pb.Begin_DT
	join udb_ctheis..SavvyPlanID_All					sp	on	sxb.SavvyPlanID				=	sp.SavvyPlanID		--looking up employer id
	join #2year											y2	on	sxb.Begin_DT				=	y2.Begin_DT			--product join to get three 2-year analysis periods from 4 years of data
	group by sp.Cust_Seg_Sys_Id, sxb.Begin_DT, Begin_Yr
	)	a
where PlanCount	=	BenePlanCount  --check to see if we have plan information for all plans employer offers
group by Cust_Seg_Sys_ID, Begin_Yr

create unique clustered index ucix_CustPlan2Yr	on udb_ctheis..cat_Customer_by_Analysis_Period	(Cust_Seg_Sys_Id, Begin_Yr)
--453078 on 9/1/15


--get set of plan details for customers that met criteria
if exists (select name from udb_ctheis.sys.objects where name = 'cat_Plans_in_Analysis')
drop table udb_ctheis..cat_Plans_in_Analysis

select distinct sxb.SavvyPlanID, sxb.Begin_DT, sxb.PLN_BEN_SET_MDL_SYS_ID
into udb_ctheis..cat_Plans_in_Analysis
from udb_ctheis..cat_Customer_by_Analysis_Period	cap
join #2year											y2	on	cap.Begin_Yr		=	y2.Begin_Yr
join udb_ctheis..SavvyPlanID_All					sp	on	cap.cust_seg_sys_id	=	sp.Cust_Seg_Sys_Id
join udb_ctheis..SavvyPlanID_to_BenSysID_by_Month	sxb	on	y2.Begin_DT			=	sxb.Begin_DT
														and	sp.SavvyPlanID		=	sxb.SavvyPlanID
where cap.PlanMonths	=	24
	and (cap.BothYearHDHP	=	0 
		or (BothYearHDHP = 12 and Year2HDHP	=	12))

create unique clustered index ucix_PlanMonth on udb_ctheis..cat_Plans_in_Analysis (SavvyPlanID, Begin_DT, PLN_BEN_SET_MDL_SYS_ID)
--929197 on 9/2/15


--get list of members by month who are associated with employers that meet above criteria
if exists (select name from udb_ctheis.sys.objects where name = 'Member_By_Month')
drop table udb_ctheis..Member_By_Month

select 
	a.MBR_SYS_ID, 
	d.Begin_DT,
	sp.SavvyPlanID
into udb_ctheis..Member_By_Month
from Galaxy_Research.dbo.Member_Coverage_Month_20150811	a
join udb_ctheis..cat_AnalysisDates						d	on	d.Begin_DT			between	a.MBR_COV_MO_ROW_EFF_DT and a.MBR_COV_MO_ROW_END_DT	--get a separate record for each month of coverage
join udb_ctheis..SavvyPlanID_All						sp	on	sp.cust_seg_sys_id		=	a.cust_seg_sys_id
															and	sp.PRDCT_CD				=	a.MED_PRDCT_1_CD
															and	sp.pln_var_subdiv_cd	=	a.pln_var_subdiv_cd
															and	sp.rpt_cd_br_cd			=	a.rpt_cd_br_cd
join udb_ctheis..cat_Plans_in_Analysis					pa	on	sp.SavvyPlanID			=	pa.SavvyPlanID
															and	d.Begin_DT				=	pa.Begin_DT

create unique clustered index ucix on udb_ctheis..Member_By_Month (Mbr_Sys_ID, Begin_Dt)
--26407921 on 8/27/15

drop table #member2year

select y2.Begin_Yr, lmi.Indv_Sys_Id
into #member2year
from udb_ctheis..Member_By_Month	mm
join #2year							y2	on	mm.Begin_DT		=	y2.Begin_DT
join MiniHPDM..lkp_mbr_indv			lmi	on	mm.MBR_SYS_ID	=	lmi.Mbr_Sys_Id
join udb_ctheis..SavvyPlanID_All	sp	on	mm.SavvyPlanID	=	sp.SavvyPlanID
group by y2.Begin_Yr, lmi.Indv_Sys_Id
having count(*)	=	24
	and count(distinct mm.Begin_DT)	=	24
	and count(distinct sp.Cust_Seg_Sys_Id)	=	1

create unique clustered index ucix_IndYr on #member2year (Indv_Sys_Id, Begin_YR)
--888353 on 9/2/15



--find all individuals with 2 years of continuous enrollment
if exists (select name from udb_ctheis.sys.objects where name = 'cat_Ind_By_Month')
drop table udb_ctheis..cat_Ind_By_Month

select lmi.Indv_Sys_Id, y2.Begin_DT, mm.SavvyPlanID, y2.Begin_YR
into udb_ctheis..cat_Ind_By_Month
from udb_ctheis..Member_By_Month	mm
join #2year							y2	on	mm.Begin_DT		=	y2.Begin_DT
join MiniHPDM..lkp_mbr_indv			lmi	on	mm.MBR_SYS_ID	=	lmi.Mbr_Sys_Id
join #member2year					m2y	on	y2.begin_yr		=	m2y.Begin_Yr
										and	lmi.Indv_Sys_Id	=	m2y.Indv_Sys_Id

create unique clustered index ucix_IndMonth on udb_ctheis..cat_Ind_By_Month (Indv_Sys_Id, Begin_DT, Begin_YR)
--21320472 9/2/15

drop table ##PlanBenefitYear

select
	im.INDV_SYS_ID,
	im.Begin_Yr,
	PlanYear				=	year(im.begin_dt),
	PreYearFlag				=	case
								when year(im.begin_dt)	=	im.Begin_yr	then	1
								else											0
								end,
	PostYearFlag				=	case
								when year(im.begin_dt)	>	im.Begin_yr	then	1
								else											0
								end,
	sp.Cust_Seg_Sys_ID,
	cap.PlanTypesOffered, 
	EmployerPlanType		=	case
								when BothYearHDHP = 0 then	'AllLow'
								when BothYearHDHP = 24 then	'AllHigh'
								when BothYearHDHP = 12 and Year2HDHP	=	12 then	'Yr2High'
								else 'OffYrMix'
								end,
	HDHP_Flag				=	max(HDHP_Flag),
	PLN_BEN_SET_MDL_SYS_ID	=	min(pa.PLN_BEN_SET_MDL_SYS_ID),
	FamilyDeductible		=	avg(FamilyDeductible*1.),
	IndividualDeductible	=	avg(IndividualDeductible*1.),
	FamilyOOP				=	avg(FamilyOOP*1.),
	IndividualOOP			=	avg(IndividualOOP*1.),
	OfficeVisitCopay		=	avg(	case
										when	Office_CostShareType	=	3	then	200.-2*Office_CostShareValue
										else	Office_CostShareValue
										end)
into ##PlanBenefitYear
from udb_ctheis..cat_Ind_By_Month					im
join udb_ctheis..cat_Plans_in_Analysis				pa	on	im.SavvyPlanID				=	pa.SavvyPlanID
														and	im.Begin_DT					=	pa.Begin_DT
join udb_ctheis..cat_Plan_Benefits					pb	on	pa.Begin_DT					=	pb.Begin_DT
														and	pa.PLN_BEN_SET_MDL_SYS_ID	=	pb.PLN_BEN_SET_MDL_SYS_ID
join udb_ctheis..SavvyPlanID_All					sp	on	im.SavvyPlanID				=	sp.SavvyPlanID
join udb_ctheis..cat_Customer_by_Analysis_Period	cap	on	sp.Cust_Seg_Sys_Id			=	cap.Cust_Seg_Sys_Id
														and im.Begin_Yr					=	cap.Begin_Yr
group by 
	im.INDV_SYS_ID,
	im.Begin_Yr,
	year(im.begin_dt),
	case
								when year(im.begin_dt)	=	im.Begin_yr	then	1
								else											0
								end,
	sp.Cust_Seg_Sys_ID,
	cap.PlanTypesOffered, 
	case
								when BothYearHDHP = 0 then	'AllLow'
								when BothYearHDHP = 24 then	'AllHigh'
								when BothYearHDHP = 12 and Year2HDHP	=	12 then	'Yr2High'
								else 'OffYrMix'
								end
having count(distinct	HDHP_Flag)	=	1

create unique clustered index ucix_IndYear on ##PlanBenefitYear (Indv_Sys_ID, Begin_Yr, PlanYear)
--1280610 on 8/27/15

--remove individuals without 2 years of data
delete ##PlanBenefitYear
from ##PlanBenefitYear	pby
join (
	select Indv_Sys_ID, Begin_Yr
	from ##PlanBenefitYear
	group by Indv_Sys_ID, Begin_Yr
	having count(*) <> 2
	)					d	on	pby.Indv_Sys_Id	=	d.Indv_Sys_Id
							and pby.Begin_Yr	=	d.Begin_Yr	




drop table #dependent

select pby.INDV_SYS_ID,	pby.PlanYear,
	Annual_Allow_Amount		=	isnull(fc.Annual_Allow_Amount,0),
	Annual_Net_Paid_Amount	=	isnull(Annual_Net_Paid_Amount,0),
	Annual_OOP_Amount		=	isnull(Annual_OOP_Amount,0),
	Annual_IP_Allow_Amount	=	isnull(Annual_IP_Allow_Amount,0),
	Annual_OP_Allow_Amount	=	isnull(Annual_OP_Allow_Amount,0),
	Annual_Dr_Allow_Amount	=	isnull(Annual_Dr_Allow_Amount,0),
	Annual_Rx_Allow_Amount	=	isnull(Annual_Rx_Allow_Amount,0)
into #dependent
from (
	select distinct Indv_Sys_Id, PlanYear
	from ##PlanBenefitYear
	)					pby
left join (
	select 
		fc.Indv_Sys_Id,
		d.Year_Nbr,
		Annual_Allow_Amount		=	sum(fc.allw_amt),
		Annual_Net_Paid_Amount	=	sum(fc.net_pd_amt),
		Annual_OOP_Amount		=	sum(fc.OOP_Amt),
		Annual_IP_Allow_Amount	=	sum(case when fc.Srvc_Typ_Sys_Id = 1 then fc.Allw_Amt end),
		Annual_OP_Allow_Amount	=	sum(case when fc.Srvc_Typ_Sys_Id = 2 then fc.Allw_Amt end),
		Annual_Dr_Allow_Amount	=	sum(case when fc.Srvc_Typ_Sys_Id = 3 then fc.Allw_Amt end),
		Annual_Rx_Allow_Amount	=	sum(case when fc.Srvc_Typ_Sys_Id = 4 then fc.Allw_Amt end)
	from MiniHPDM..Fact_Claims	fc	
	join MiniHPDM..Dim_Date		d	on	fc.dt_sys_id	=	d.dt_sys_id
	group by 
		fc.Indv_Sys_Id,
		d.Year_Nbr
	)					fc	on	pby.Indv_Sys_ID	=	fc.Indv_Sys_ID
							and	pby.PlanYear	=	fc.year_nbr

create unique clustered index ucix_IndYear on #dependent (Indv_Sys_ID, PlanYear)
--1489867 on 9/2/15

--run Get RAF score scripts at this point
drop table #RAF

select 
	Indv_Sys_ID	=	UniqueMemberID,
	RAF			=	TotalScore,
	PlanYear	=	2011
into #RAF
from udb_ctheis..RA_Com_P_MetalScores_2011
where ModelVersion	=	'Silver'
union
select 
	Indv_Sys_ID	=	UniqueMemberID,
	RAF			=	TotalScore,
	PlanYear	=	2012
from udb_ctheis..RA_Com_P_MetalScores_2012
where ModelVersion	=	'Silver'
union
select 
	Indv_Sys_ID	=	UniqueMemberID,
	RAF			=	TotalScore,
	PlanYear	=	2013
from udb_ctheis..RA_Com_P_MetalScores_2013
where ModelVersion	=	'Silver'
union
select 
	Indv_Sys_ID	=	UniqueMemberID,
	RAF			=	TotalScore,
	PlanYear	=	2014
from udb_ctheis..RA_Com_P_MetalScores_2014
where ModelVersion	=	'Silver'
--1489663 on 9/2/15

--create a table to indicate who has HDHP in 2nd year
select Indv_Sys_ID, Begin_Yr, HDHP_Flag
into #HDHP
from ##PlanBenefitYear
where HDHP_Flag = 1

create unique clustered index ucix_Ind_Yr on #HDHP (Indv_Sys_Id, Begin_Yr)

drop table udb_ctheis..cat_Final_Analysis_Set

select 
	HDHP_Yr2_Flag =	isnull(h.HDHP_Flag, 0), --indicates if plan in year 2 is high deductible
	NoChoice_Flag = case when pby.PlanTypesOffered <> 'Both' then 1 else 0 end,
	PlanYear2OfferAndChoice	=	case when pby.PlanTypesOffered = 'Both' then 'Choice' else 'No Choice' end+'-'+case when h.HDHP_Flag	=	1	then 'CD' else 'LD' end,
	pby.*, 
	m.Age,
	m.Gdr_Cd,
	r.RAF,
	d.Annual_Allow_Amount,
	Annual_Net_Paid_Amount,
	Annual_OOP_Amount,
	Annual_IP_Allow_Amount,
	Annual_OP_Allow_Amount,
	Annual_Dr_Allow_Amount,
	Annual_Rx_Allow_Amount
into udb_ctheis..cat_Final_Analysis_Set
from ##PlanBenefitYear		pby
join #dependent				d	on	pby.Indv_Sys_ID	=	d.Indv_Sys_ID
								and	pby.PlanYear	=	d.PlanYear
join #RAF					r	on	pby.Indv_Sys_ID	=	r.Indv_Sys_ID
								and pby.PlanYear	=	r.PlanYear
join miniHPDM..dim_Member	m	on	pby.Indv_Sys_Id	=	m.Indv_Sys_Id
left join #HDHP				h	on	pby.Indv_Sys_Id	=	h.Indv_Sys_Id
								and pby.Begin_Yr	=	h.Begin_Yr
where m.Gdr_CD in ('M','F')
	and m.Age < 65
	and pby.Begin_Yr in (2012,2013)

create unique clustered index ucix_IndYear on udb_ctheis..cat_Final_Analysis_Set (Indv_Sys_ID, Begin_Yr, PlanYear)
--1463639 on 4/16/16

--remove individuals that had a negative amount in either year
delete udb_ctheis..cat_Final_Analysis_Set
from udb_ctheis..cat_Final_Analysis_Set	fas
join (
	select distinct Indv_Sys_ID, Begin_Yr
	from udb_ctheis..cat_Final_Analysis_Set
	where Annual_Allow_Amount		< 0
		or  Annual_IP_Allow_Amount	< 0
		or  Annual_OP_Allow_Amount	< 0
		or  Annual_Dr_Allow_Amount	< 0
		or  Annual_Rx_Allow_Amount	< 0
	)									lb	on	fas.INDV_SYS_ID	=	lb.INDV_SYS_ID
											and	fas.Begin_Yr	=	lb.Begin_Yr
--158

--remove individuals that had over 250K allowed amount in either year
delete udb_ctheis..cat_Final_Analysis_Set
from udb_ctheis..cat_Final_Analysis_Set	fas
join (
	select distinct Indv_Sys_ID, Begin_Yr
	from udb_ctheis..cat_Final_Analysis_Set
	where Annual_Allow_Amount		> 250000
	)									lb	on	fas.INDV_SYS_ID	=	lb.INDV_SYS_ID
											and	fas.Begin_Yr	=	lb.Begin_Yr
--1488 eliminated  


--summary statistics


--how many employers meet criteria set 2 by analysis period?
select Begin_Yr, 
	count(*)
from udb_ctheis..cat_Customer_by_Analysis_Period
group by Begin_Yr
order by Begin_Yr

--how many employers meet criteria set 3 by analysis period?
select Begin_Yr, 
	count(*)
from udb_ctheis..cat_Customer_by_Analysis_Period
where PlanMonths	= 24
group by Begin_Yr
order by Begin_Yr

--how many employers are in each offer type bucket?
select Begin_Yr, 
	EmpOfferType	=	case
						when BothYearHDHP = 0 then	'AllLow'
						when BothYearHDHP = 24 then	'AllHigh'
						when BothYearHDHP = 12 and Year2HDHP	=	12 then	'Yr2High'
						else 'OffYrMix'
						end,
	count(*)
from udb_ctheis..cat_Customer_by_Analysis_Period
where PlanMonths	= 24
group by Begin_Yr,case
						when BothYearHDHP = 0 then	'AllLow'
						when BothYearHDHP = 24 then	'AllHigh'
						when BothYearHDHP = 12 and Year2HDHP	=	12 then	'Yr2High'
						else 'OffYrMix'
						end
order by EmpOfferType, Begin_Yr

--how many employers and inviduals are left after criteria 4 by Begin Yr?
select Begin_Yr,   count(distinct Indv_Sys_Id), count(distinct cust_seg_sys_id)
from udb_ctheis..cat_Final_Analysis_Set
where PreYearFlag	=	1
group by Begin_Yr
order by Begin_Yr


--how many employers and inviduals are left after criteria 4 by Plan Offer Type?
select Begin_Yr, EmployerPlanType, 
	PlanTypesOffered,  count(distinct Indv_Sys_Id), count(distinct cust_seg_sys_id)
from udb_ctheis..cat_Final_Analysis_Set
where PreYearFlag	=	1
group by Begin_Yr, EmployerPlanType,
	PlanTypesOffered
order by 
	PlanTypesOffered,
	EmployerPlanType,
	Begin_Yr

--to get a true acturial richness, you probably need history for at least 100 individuals
--if we limited to plans where a true actuarial richness, we would lose almost half of the treatment group
select *
from (
	--get a actuarial value by plan based on utilization
	select 
		PlanRichness	=	sum(Annual_Net_Paid_Amount)/sum(case when Annual_Allow_Amount = 0 then 1. else Annual_Allow_Amount end),
		Individuals		=	count(*), 
		PLN_BEN_SET_MDL_SYS_ID, Begin_Yr, PlanYear
	from udb_ctheis..cat_Final_Analysis_Set
	where Begin_Yr	> 2011
	group by PLN_BEN_SET_MDL_SYS_ID, Begin_Yr, PlanYear
	)	a
join udb_ctheis..cat_Final_Analysis_Set	b	on	a.PLN_BEN_SET_MDL_SYS_ID	=	b.PLN_BEN_SET_MDL_SYS_ID
											and	a.Begin_Yr					=	b.Begin_Yr
											and a.PlanYear					=	b.PlanYear
where b.PlanTypesOffered	= 'HDHP'
	and PreYearFlag = 0
	and Individuals	> 100