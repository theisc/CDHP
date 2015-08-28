/*
The purpose of this script is to be able to identify the benefit set for any individual at any point in time.
Approach is to assign benefits to each member on the 1st of every month they are enrolled.


Input Tables:
MiniHPDM..Dim_Date
MiniHPDM..lkp_mbr_indv	

The following were extracted from Galaxy using queries as written in Galaxy_Pull.sql
Galaxy_Research.dbo.Member_Coverage_Month_2050331
select count(*) from Galaxy_Research.dbo.Customer_Segment_Coverage_20150811	--2260346

Created By: Curt
Created On: 8/6/13 

Updated By: Curt
Updated On: 8/1/15

select count(*) from Galaxy_Research.dbo.Member_Coverage_Month_20150331			--114782228
select count(*) from Galaxy_Research.dbo.Customer_Segment_Coverage_20150811	--1760364

Output Tables:


*/

--server devsql10
use udb_Ctheis
go

--create table with one record per month for 2011 - 2014; 48 records
drop table udb_ctheis..cat_AnalysisDates

select dt1.YEAR_NBR, 
	convert(varchar, dt1.YEAR_MO)	as	YEAR_MO, 
	dt1.FULL_DT						as	Begin_DT,
	dt2.FULL_DT						as	End_DT
into udb_ctheis..cat_AnalysisDates
from MiniHPDM.dbo.Dim_Date				dt1 with (nolock)
inner join MiniHPDM.dbo.Dim_Date		dt2 with (nolock) on dt1.YEAR_MO  = dt2.YEAR_MO  --joining to get first and last day of every month
where dt1.DAY_NBR			= 1		--first day of month only from table 1
	and dt2.LST_DAY_MO_IND	= 'Y'	--last day of month only from table 2
	and dt1.YEAR_NBR		between 2011	and	2014	--only interested in benefits in 2011 through 2013
Go
create clustered index cix_YearMo on udb_ctheis..cat_AnalysisDates(YEAR_MO)
create index ix_FullDt on udb_ctheis..cat_AnalysisDates(Begin_Dt)
Go

--get additional attributes for customer segments.  A separate query determined that we should exclude public sector.
drop table udb_ctheis..Dim_CustSegDemographics_Detail

select
		 CUST_SEG_SYS_ID
		,YEAR_MO
		,CO_CD_SYS_ID
		,CO_SYS_ID
		,SRC_SYS_COMBO_SYS_ID
		,GRP_IND_SYS_ID
		,FINC_GRP_IND_SYS_ID
		,FINC_CO_SYS_ID
		,MED_FILTER_FLG
		,FINC_FILTER_FLG
into udb_ctheis..Dim_CustSegDemographics_Detail
from	(
	select 
		 CUST_SEG_SYS_ID
		,YEAR_MO
		,CO_CD_SYS_ID
		,CO_SYS_ID
		,SRC_SYS_COMBO_SYS_ID
		,GRP_IND_SYS_ID
		,FINC_GRP_IND_SYS_ID
		,FINC_CO_SYS_ID
		,MED_FILTER_FLG
		,FINC_FILTER_FLG
		,RN	=	ROW_NUMBER() over (partition by Cust_Seg_Sys_ID, Year_MO order by Freq desc)
	from (
		select  
			fd.CUST_SEG_SYS_ID
			,d.YEAR_MO
			,CO_CD_SYS_ID
			,CO_SYS_ID
			,SRC_SYS_COMBO_SYS_ID
			,GRP_IND_SYS_ID
			,FINC_GRP_IND_SYS_ID
			,FINC_CO_SYS_ID
			,MED_FILTER_FLG
			,FINC_FILTER_FLG
			,Freq	=	count(*)
		from MiniHPDM..Fact_Demographics		fd
		join MiniHPDM..Dim_Date					d	on	fd.DT_SYS_ID		=	d.DT_SYS_ID
		where d.YEAR_NBR	between	2011 and 2014
		group by
			fd.CUST_SEG_SYS_ID
			,d.YEAR_MO
			,CO_CD_SYS_ID
			,CO_SYS_ID
			,SRC_SYS_COMBO_SYS_ID
			,GRP_IND_SYS_ID
			,FINC_GRP_IND_SYS_ID
			,FINC_CO_SYS_ID
			,MED_FILTER_FLG
			,FINC_FILTER_FLG
		)	a
	)	b
where RN	=	1
--6599934 on 8/19/15
create unique clustered index ucix_CustSegYearMo	on	udb_ctheis..Dim_CustSegDemographics_Detail (CUST_SEG_SYS_ID ,YEAR_MO);

--run once: create integer value to represent combinations of Cust_Seg_Sys_Id, PRDCT_CD, PLN_VAR_SUBDIV_CD, RPT_CD_BR_CD
--simplifies future joins and saves space
if exists (select name from udb_ctheis.sys.objects where name = 'SavvyPlanID_All')
drop table udb_ctheis..SavvyPlanID_All

create table udb_ctheis..SavvyPlanID_All(
	SavvyPlanID			int identity(1,1),
	Cust_Seg_Sys_Id		int, 
	PRDCT_CD			varchar(5), 
	PLN_VAR_SUBDIV_CD	varchar(4), 
	RPT_CD_BR_CD		varchar(4)
	)

insert into udb_ctheis..SavvyPlanID_All (
	a.Cust_Seg_Sys_Id, PRDCT_CD, PLN_VAR_SUBDIV_CD, RPT_CD_BR_CD)
select 
	c.Cust_Seg_Sys_Id, c.PRDCT_CD, c.PLN_VAR_SUBDIV_CD, c.RPT_CD_BR_CD
from (
	select distinct 
		Cust_Seg_Sys_Id, PRDCT_CD, PLN_VAR_SUBDIV_CD, RPT_CD_BR_CD
	from Galaxy_Research.dbo.Customer_Segment_Coverage_20150811
	)	c
join (
	select distinct 
		Cust_Seg_Sys_Id, MED_PRDCT_1_CD, PLN_VAR_SUBDIV_CD, RPT_CD_BR_CD
	from Galaxy_Research.dbo.Member_Coverage_Month_20150811
	)	m	on 	c.cust_seg_sys_id		=	m.cust_seg_sys_id	--limit to combinations that exist in both the member and employer table
			and	c.PRDCT_CD				=	m.MED_PRDCT_1_CD
			and	c.pln_var_subdiv_cd		=	m.pln_var_subdiv_cd
			and	c.rpt_cd_br_cd			=	m.rpt_cd_br_cd

create unique clustered index ucix_Plan on udb_ctheis..SavvyPlanID_All (Cust_Seg_Sys_Id, PRDCT_CD, PLN_VAR_SUBDIV_CD, RPT_CD_BR_CD) with (sort_in_tempdb = on); 
create index ix_PlanID on udb_ctheis..SavvyPlanID_All (SavvyPlanID) with (sort_in_tempdb = on); 
--641339 on 8/19/15

--Customer_Segment_Plan_Benefit_20150820
	--links plan identifiers to benefit model system identifier
	--should be unique on plan identifiers, date and update date  
		--there are lots of duplicates even including update date which is troublesome
		--however, each points to a different pln_ben_mdl_sys_id and it is assumed the most recent update date is the correct one
if exists (select name from udb_ctheis.sys.objects where name = 'SavvyPlanID_to_BenSysID_by_Month')
drop table udb_ctheis..SavvyPlanID_to_BenSysID_by_Month

select
	a.SavvyPlanID, 
	a.Begin_DT,
	a.PLN_BEN_SET_MDL_SYS_ID
into udb_ctheis..SavvyPlanID_to_BenSysID_by_Month
from (
	select 
		sp.SavvyPlanID,
		d.Begin_DT,
		csc.PLN_BEN_SET_MDL_SYS_ID,
		rn	=	row_number() over (partition by sp.SavvyPlanID, d.Begin_DT order by csc.updt_dt desc)  
	from Galaxy_Research..Customer_Segment_Plan_Benefit_20150820	csc	
	join #tmpDates													d	on	d.Begin_DT			between csc.CUST_SEG_PLN_BEN_EFF_DT  and csc.CUST_SEG_PLN_BEN_END_DT
	join udb_ctheis..SavvyPlanID_All								sp	on	sp.cust_seg_sys_id		=	csc.cust_seg_sys_id
																		and	sp.PRDCT_CD				=	csc.prdct_cd
																		and	sp.pln_var_subdiv_cd	=	csc.pln_var_subdiv_cd
																		and	sp.rpt_cd_br_cd			=	csc.rpt_cd_br_cd
	join (--we only have complete plan information for UHC fully-insured plans
		select cust_seg_sys_id, 
			Begin_Dt	=	cast(Year_Mo+'01'	as date)
		from MiniHPDM..Dim_CustSegSysId_Detail
		where Co_Id_Rllp			=	'United Healthcare'			--original UHC plans
			and Hlth_Pln_Fund_Cd	=	'FI'						--fully-insured
		)														c	on	csc.CUST_SEG_SYS_ID	=	c.Cust_Seg_Sys_Id	--limit to plans with these customer segments
																	and	d.Begin_DT			=	c.Begin_Dt
	join (
		select cust_seg_sys_id, 
			Begin_Dt	=	cast(Year_Mo+'01'	as date)
		from udb_ctheis..Dim_CustSegDemographics_Detail	a
		where grp_ind_sys_id <> 12  --exclude public sector
		)														nps	on	csc.CUST_SEG_SYS_ID	=	nps.Cust_Seg_Sys_Id	--only 24% of public sector member months had details	
																	and	d.Begin_DT			=	nps.Begin_Dt
	)	a
where rn	=	1  --overlapping dates occur in plan benefit, need to select date with most recent update date

create unique clustered index ix_plan_ben_set on udb_ctheis..SavvyPlanID_to_BenSysID_by_Month	(SavvyPlanID, Begin_DT)
--8049451 records on 8/20/15

select 
	a.MBR_SYS_ID, 
	d.YEAR_NBR
into #MemberFullYear
from Galaxy_Research.dbo.Member_Coverage_Month_20150811	a
join #tmpDates											d	on	d.Begin_DT			between	a.MBR_COV_MO_ROW_EFF_DT and a.MBR_COV_MO_ROW_END_DT	--get a separate record for each month of coverage		
group by a.MBR_SYS_ID, 
	d.YEAR_NBR
having count(distinct d.Begin_DT)	=	12

create unique clustered index ucix on #MemberFullYear (Mbr_Sys_ID,Year_Nbr)

select	MBR_SYS_ID, 2011 as BeginYear
into udb_ctheis..cat_2YearMember
from #MemberFullYear
where YEAR_NBR	between 2011 and 2012
group by MBR_SYS_ID
having count(*)	=	2
union
select	MBR_SYS_ID, 2012
from #MemberFullYear
where YEAR_NBR	between 2012 and 2013
group by MBR_SYS_ID
having count(*)	=	2
union
select	MBR_SYS_ID, 2013
from #MemberFullYear
where YEAR_NBR	between 2013 and 2014
group by MBR_SYS_ID
having count(*)	=	2

create unique clustered index ucix on udb_ctheis..cat_2YearMember (Mbr_Sys_ID, BeginYear)
--45223583 on 20150824

--run once: get list of fully enrolled members over 
if exists (select name from udb_ctheis.sys.objects where name = 'Member_By_Month')
drop table udb_ctheis..Member_By_Month


select 
	MBR_SYS_ID, 
	Begin_DT, 
	SavvyPlanID
into udb_ctheis..Member_By_Month
from (
select 
		a.MBR_SYS_ID, 
		d.Begin_DT, 
		sp.SavvyPlanID,
		rn	=	row_number() over (partition by a.MBR_SYS_ID, d.Begin_DT order by a.updt_dt desc) 
	from Galaxy_Research.dbo.Member_Coverage_Month_20150811	a
	join #tmpDates											d	on	d.Begin_DT			between	a.MBR_COV_MO_ROW_EFF_DT and a.MBR_COV_MO_ROW_END_DT	--get a separate record for each month of coverage
	join #MemberFull2Year									f2y	on	a.MBR_SYS_ID			=	f2y.MBR_SYS_ID
	join #MemberFullYear									fy	on	a.MBR_SYS_ID			=	fy.MBR_SYS_ID
																and	d.YEAR_NBR				=	fy.YEAR_NBR		
	join udb_ctheis..SavvyPlanID_All						sp	on	sp.cust_seg_sys_id		=	a.cust_seg_sys_id
																and	sp.PRDCT_CD				=	a.MED_PRDCT_1_CD
																and	sp.pln_var_subdiv_cd	=	a.pln_var_subdiv_cd
																and	sp.rpt_cd_br_cd			=	a.rpt_cd_br_cd
	)	a
where rn = 1  --only 180 out 720M have more than 1 record in 1 month

--12227141  on 8/10/15

create unique clustered index ucix_mbr_mnth on udb_ctheis..Member_By_Month (Mbr_Sys_ID, Begin_DT)



join MiniHPDM..lkp_mbr_indv								lmi	on	a.MBR_SYS_ID	=	lmi.Mbr_Sys_Id



select MBR_SYS_ID, 
		Begin_DT
from udb_ctheis..Member_By_Month
group by MBR_SYS_ID, 
		Begin_DT
having count(*) > 1