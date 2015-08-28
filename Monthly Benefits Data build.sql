/*
The purpose of this script is to be able to identify the benefit set for any point in time.
Approach is to assign benefits to the 1st of every month since benefits data is unique at the plan benefit set and date level.


Input Tables:
MiniHPDM..Dim_Date

The following were extracted from Galaxy using queries as written in Galaxy_Pull.sql
select count(*) from Galaxy_Research.dbo.Plan_Benefit_Set_Model_20150811		--646926
select count(*) from Galaxy_Research.dbo.Plan_Benefit_Set_Liability_20150811	--2953560
select count(*) from Galaxy_Research.dbo.Plan_Benefit_Service_20150811			--2225118
select count(*) from Galaxy_Research.dbo.Benefit_Liability_Type_20150811		--6
select count(*) from Galaxy_Research..Service_Event_20150811					--35

Output Tables:
select count(*) from udb_ctheis..Benefit_Set_Model_Plan_by_Month				--24396403
select count(*) from udb_ctheis..Service_Event_Benefit_Set_by_Month				--23919404
select count(*) from udb_ctheis..Liability_Set_by_Month							--22542396

Created By: Curt
Created On: 8/6/13 

Updated By: Curt
Updated On: 8/19/15
*/

--server devsql10
use udb_Ctheis
go

--create table with one record per month for 2011 - 2014; 48 records
drop table #tmpDates

select dt1.YEAR_NBR, 
	convert(varchar, dt1.YEAR_MO)	as	YEAR_MO, 
	dt1.FULL_DT						as	Begin_DT,
	dt2.FULL_DT						as	End_DT
into #tmpDates
from MiniHPDM.dbo.Dim_Date				dt1 with (nolock)
inner join MiniHPDM.dbo.Dim_Date		dt2 with (nolock) on dt1.YEAR_MO  = dt2.YEAR_MO  --joining to get first and last day of every month
where dt1.DAY_NBR			= 1		--first day of month only from table 1
	and dt2.LST_DAY_MO_IND	= 'Y'	--last day of month only from table 2
	and dt1.YEAR_NBR		between 2011	and	2014	--only interested in benefits in 2011 through 2013
Go
create clustered index cix_YearMo on #tmpDates(YEAR_MO)
create index ix_FullDt on #tmpDates(Begin_Dt)
Go


--plan benefit set model 
	--has high level information about benefit set 
	--unique on PLN_BEN_SET_MDL_SYS_ID, date and update date
if exists (select name from udb_ctheis.sys.objects where name = 'Benefit_Set_Model_Plan_by_Month')
drop table udb_ctheis..Benefit_Set_Model_Plan_by_Month

--create a table with one record per PLN_BEN_SET_MDL_SYS_ID and month
select   
	Begin_DT,
	PLN_BEN_SET_MDL_SYS_ID,
	MDL_PLN_NBR, MDL_POL_NBR, SRC_SYS_CD, SRC_SYS_GRP_CD, COV_TYP_CD, FINC_ARNG_CD, PLN_INFO_RPTBL_IND, PLN_YR_TXT, PRDCT_CD, RISK_CLSS_TXT
into udb_ctheis..Benefit_Set_Model_Plan_by_Month
from (
	select PLN_BEN_SET_MDL_SYS_ID, Begin_Dt,
		pbsm.MDL_PLN_NBR, MDL_POL_NBR, SRC_SYS_CD, SRC_SYS_GRP_CD, COV_TYP_CD, FINC_ARNG_CD, PLN_INFO_RPTBL_IND, 
		PLN_YR_TXT	=	cast(case when PLN_YR_TXT = 'PRE-1998' then 1997 else PLN_YR_TXT end as smallint), 
		PRDCT_CD, RISK_CLSS_TXT,
		rn			=	row_number() over (partition by PLN_BEN_SET_MDL_SYS_ID, a.Begin_DT order by pbsm.Updt_Dt desc)
	from #tmpDates												a
	join Galaxy_Research.dbo.Plan_Benefit_Set_Model_20150811	pbsm	on	a.Begin_DT	between pbsm.PLN_BEN_SET_MDL_ROW_EFF_DT	and	pbsm.PLN_BEN_SET_MDL_ROW_END_DT
	)	a
where a.rn	= 1  --overlapping dates occur in plan benefit, need to select date with most recent update date

create unique clustered index ix_plan_ben_set on udb_ctheis..Benefit_Set_Model_Plan_by_Month (PLN_BEN_SET_MDL_SYS_ID, Begin_DT)
--1764174 on 8/19/15

/*
--Lookup table for unpivoting service event data
create table udb_ctheis..CostShareType (
	CostShareTypeCd	tinyint,
	CostShareType varchar(25)
	)

insert into udb_ctheis..CostShareType values (1, 'Visit Copay')
insert into udb_ctheis..CostShareType values (2, 'Admit Copay')
insert into udb_ctheis..CostShareType values (3, 'Coinsurance')

*/

--plan benefit service
	--has details about about member cost responsibility for various health care
	--unique on PLN_BEN_SET_MDL_SYS_ID, Srvc_Evnt_ID, date and update date  (after filtering on in-network)

--reformat service benefits
drop table #Plan_Benefit_Service_Subset

select PLN_BEN_SET_MDL_SYS_ID, PLN_BEN_SRVC_ROW_EFF_DT,	PLN_BEN_SRVC_ROW_END_DT, SRVC_EVNT_ID, BEN_COINS_PCT, BEN_COINS_BAS_TXT, BEN_COPAY_AMT, BEN_COPAY_BAS_TXT
	, CostShareTypeCd	=	case
								when BEN_COPAY_BAS_TXT	=	'Per Visit'				then	1
								when BEN_COPAY_BAS_TXT	=	'Per Inpatient Stay'	then	2
								when BEN_COINS_PCT		=	100						then	1 --change 100% coinsurance to $0 copay
								else														3
							end
	, CostShareValue	=	case
								when BEN_COPAY_BAS_TXT	in	('Per Visit','Per Inpatient Stay')	then	BEN_COPAY_AMT
								when BEN_COINS_PCT		=	100									then	0
								else																	BEN_COINS_PCT
							end
	, Updt_Dt
into #Plan_Benefit_Service_Subset
from Galaxy_Research.dbo.Plan_Benefit_Service_20150811	pbs
/*filtered in galaxy pull
where pbs.Srvc_Evnt_ID			in		(254,835,1611,105)						--only interested in 4 main types of services
	--excluding oddball stuff; these last two filters exclude <7% of rows
	and (BEN_COPAY_AMT	= 0 
		or	 ben_coins_pct = 100)												--Exclude services with both copay and coins

--Srvc_Evnt_ID	Srvc_Evnt_Nm
--254			SURGICAL/RAPL OUTPATIENT FACILITY REVENUE CODES
--835			URGENT CARE SERVICES
--1611			OFFICE OR OUTPATIENT VISITS
--105			EMERGENCY HEALTH SERVICES
*/
create unique clustered index ucix_pbs on #Plan_Benefit_Service_Subset (PLN_BEN_SET_MDL_SYS_ID, SRVC_EVNT_ID, PLN_BEN_SRVC_ROW_EFF_DT) with (sort_in_tempdb = on);
--2225118 on 8/19/15


--distill service benefit table and pivot data to one record per plan and month
if exists (select name from udb_ctheis.sys.objects where name = 'Service_Event_Benefit_Set_by_Month')
drop table udb_ctheis..Service_Event_Benefit_Set_by_Month;

with 

cte_distill as (

	select  PLN_BEN_SET_MDL_SYS_ID, Begin_DT, SRVC_EVNT_ID,
		CostShareTypeCd, CostShareValue
	from (
		select pbs.PLN_BEN_SET_MDL_SYS_ID, Begin_DT, SRVC_EVNT_ID
			, CostShareTypeCd	
			, CostShareValue	
			, rn	=	row_number() over (partition by pbs.PLN_BEN_SET_MDL_SYS_ID, SRVC_EVNT_ID, Begin_DT order by pbs.updt_dt desc)
		from #Plan_Benefit_Service_Subset	pbs
		join #tmpDates						d	on	d.Begin_Dt				between pbs.PLN_BEN_SRVC_ROW_EFF_DT	and	pbs.PLN_BEN_SRVC_ROW_END_DT	--getting one record per month of interest
		)	a
	where rn = 1
	)
--creating final set of service benefits
--limiting to only plans that have all four benefits covered and have only a copay or coinsurance for each  (excludes about 25% of plans)
select 
	a.*,
	ER_CostShareType		=	b.CostShareTypeCd,
	ER_CostShareValue		=	b.CostShareValue,
	OpSurg_CostShareType	=	c.CostShareTypeCd,
	OpSurg_CostShareValue	=	c.CostShareValue,
	Urgent_CostShareType	=	d.CostShareTypeCd,
	Urgent_CostShareValue	=	d.CostShareValue,
	Office_CostShareType	=	e.CostShareTypeCd,
	Office_CostShareValue	=	e.CostShareValue
into udb_ctheis..Service_Event_Benefit_Set_by_Month
from   (
			select distinct 
				PLN_BEN_SET_MDL_SYS_ID,	
				Begin_Dt
			from cte_distill
			)	a
left 
join  (
	select PLN_BEN_SET_MDL_SYS_ID, Begin_Dt, CostShareTypeCd, CostShareValue,
		Srvc_Evnt	=	'ER'
	from cte_distill
	where SRVC_EVNT_ID	=	105  --ER
	)				b	on	a.PLN_BEN_SET_MDL_SYS_ID	=	b.PLN_BEN_SET_MDL_SYS_ID
						and	a.Begin_Dt					=	b.Begin_Dt	
left 
join ( --inner joins only include plans that have all 4 benefits identified
	select PLN_BEN_SET_MDL_SYS_ID, Begin_Dt, CostShareTypeCd, CostShareValue,
		Srvc_Evnt	=	'OP-Surg'
	from cte_distill
	where SRVC_EVNT_ID	=	254
	)				c	on	a.PLN_BEN_SET_MDL_SYS_ID	=	c.PLN_BEN_SET_MDL_SYS_ID
						and	a.Begin_Dt					=	c.Begin_Dt
left 
join (
	select PLN_BEN_SET_MDL_SYS_ID, Begin_Dt, CostShareTypeCd, CostShareValue,
		Srvc_Evnt	=	'Urgent'
	from cte_distill
	where SRVC_EVNT_ID	=	835
	)				d	on	a.PLN_BEN_SET_MDL_SYS_ID	=	d.PLN_BEN_SET_MDL_SYS_ID
						and	a.Begin_Dt					=	d.Begin_Dt
left 
join (
	select PLN_BEN_SET_MDL_SYS_ID, Begin_Dt, CostShareTypeCd, CostShareValue,
		Srvc_Evnt	=	'Office'
	from cte_distill
	where SRVC_EVNT_ID	=	1611
	)				e	on	a.PLN_BEN_SET_MDL_SYS_ID	=	e.PLN_BEN_SET_MDL_SYS_ID
						and	a.Begin_Dt					=	e.Begin_Dt

create unique clustered index ucix_Pln_Mnth on udb_ctheis..Service_Event_Benefit_Set_by_Month (PLN_BEN_SET_MDL_SYS_ID, Begin_Dt)
--23919404 on 8/19/15


--plan benefit liability
	--has details about about member deductibles and max OOP
	--unique on PLN_BEN_SET_MDL_SYS_ID, Ben_Liab_Typ_Id, date and update date  (after filtering on in-network)

--create subset of liabilities
drop table #Plan_Benefit_Liability_Subset

select PLN_BEN_SET_MDL_SYS_ID, PLN_BEN_SET_LIAB_ROW_EFF_DT,	PLN_BEN_SET_LIAB_ROW_END_DT, BEN_LIAB_TYP_ID, 
	BEN_LMT_NBR		=	case 
						when BEN_LMT_BAS_TXT in ('NO FAMILY OOP','NO FAMILY DEDUCTIBLE','NO INDIVIDUAL OOP','NO INDIVIDUAL DEDUCTIBLE') then 0 
						else BEN_LMT_NBR 
						end, --set to zero as some liabilities use negative numbers to indicate something unknown
	BEN_LMT_BAS_CD	=	case 
						when BEN_LMT_BAS_TXT in ('NO FAMILY OOP','NO FAMILY DEDUCTIBLE','NO INDIVIDUAL OOP','NO INDIVIDUAL DEDUCTIBLE') then 0
						when BEN_LMT_BAS_TXT =	'PER CALENDAR YEAR'																		then 1
						when BEN_LMT_BAS_TXT =	'PER POLICY YEAR'																		then 2
						end, --set all 0 cost to 0 none leaving 3 types 
	UPDT_DT
into #Plan_Benefit_Liability_Subset

from Galaxy_Research.dbo.Plan_Benefit_Set_Liability_20150811
where Ben_Liab_Typ_Id	in		(21,22,23,24)	--only interested in deductible and Max OOP for family & ind; ignoring lifetime max
	--only including 6 main types accounting for over 99% of liabilities   
	and BEN_LMT_BAS_TXT in ('NO FAMILY OOP','NO FAMILY DEDUCTIBLE','NO INDIVIDUAL OOP','NO INDIVIDUAL DEDUCTIBLE','PER CALENDAR YEAR','PER POLICY YEAR')                                                                               

create unique clustered index ucix_pbs on #Plan_Benefit_Liability_Subset (PLN_BEN_SET_MDL_SYS_ID, BEN_LIAB_TYP_ID, PLN_BEN_SET_LIAB_ROW_EFF_DT) with (sort_in_tempdb = on);
--2386728 on 8/19/2015

--distill liability table and pivot to one record per plan and month
if exists (select name from udb_ctheis.sys.objects where name = 'Liability_Set_by_Month')
drop table udb_ctheis..Liability_Set_by_Month;

with 

cte_distill as (

	select  PLN_BEN_SET_MDL_SYS_ID, Begin_DT, BEN_LIAB_TYP_ID, BEN_LMT_NBR, BEN_LMT_BAS_CD
	from (
		select pls.PLN_BEN_SET_MDL_SYS_ID, d.Begin_DT, BEN_LIAB_TYP_ID, BEN_LMT_NBR, BEN_LMT_BAS_CD	
			, rn	=	row_number() over (partition by pls.PLN_BEN_SET_MDL_SYS_ID, Ben_Liab_Typ_Id, d.Begin_DT order by pls.updt_dt desc)
		from #Plan_Benefit_Liability_Subset	pls
		join #tmpDates						d	on	d.Begin_Dt	between pls.PLN_BEN_SET_LIAB_ROW_EFF_DT	and	pls.PLN_BEN_SET_LIAB_ROW_END_DT	--getting one record per month of interest
		)	a
	where rn = 1
	)
--creating final set of liabilities
select 
	a.*,
	IndividualDeductibleType	=	b.BEN_LMT_BAS_CD,
	IndividualDeductible		=	b.BEN_LMT_NBR,
	FamilyDeductibleType		=	c.BEN_LMT_BAS_CD,
	FamilyDeductible			=	c.BEN_LMT_NBR,
	IndividualOOPType			=	d.BEN_LMT_BAS_CD,
	IndividualOOP				=	d.BEN_LMT_NBR,
	FamilyOOPType				=	e.BEN_LMT_BAS_CD,
	FamilyOOP					=	e.BEN_LMT_NBR
into udb_ctheis..Liability_Set_by_Month
from   (
			select distinct 
				PLN_BEN_SET_MDL_SYS_ID,	
				Begin_Dt
			from cte_distill
			)	a
left 
join  (
	select PLN_BEN_SET_MDL_SYS_ID, Begin_Dt, BEN_LMT_NBR, BEN_LMT_BAS_CD,
		Liab	=	'Ind Ded'
	from cte_distill
	where BEN_LIAB_TYP_ID	=	21
	)				b	on	a.PLN_BEN_SET_MDL_SYS_ID	=	b.PLN_BEN_SET_MDL_SYS_ID
						and	a.Begin_Dt					=	b.Begin_Dt	
left 
join ( --inner joins only include plans that have all 4 benefits identified
	select PLN_BEN_SET_MDL_SYS_ID, Begin_Dt, BEN_LMT_NBR, BEN_LMT_BAS_CD,
		Liab	=	'Fam Ded'
	from cte_distill
	where BEN_LIAB_TYP_ID	=	22
	)				c	on	a.PLN_BEN_SET_MDL_SYS_ID	=	c.PLN_BEN_SET_MDL_SYS_ID
						and	a.Begin_Dt					=	c.Begin_Dt
left 
join (
	select PLN_BEN_SET_MDL_SYS_ID, Begin_Dt, BEN_LMT_NBR, BEN_LMT_BAS_CD,
		Liab	=	'Ind Max'
	from cte_distill
	where BEN_LIAB_TYP_ID	=	23
	)				d	on	a.PLN_BEN_SET_MDL_SYS_ID	=	d.PLN_BEN_SET_MDL_SYS_ID
						and	a.Begin_Dt					=	d.Begin_Dt
left 
join (
	select PLN_BEN_SET_MDL_SYS_ID, Begin_Dt, BEN_LMT_NBR, BEN_LMT_BAS_CD,
		Liab	=	'Fam Max'
	from cte_distill
	where BEN_LIAB_TYP_ID	=	24
	)				e	on	a.PLN_BEN_SET_MDL_SYS_ID	=	e.PLN_BEN_SET_MDL_SYS_ID
						and	a.Begin_Dt					=	e.Begin_Dt

create unique clustered index ucix_Pln_Mnth on udb_ctheis..Liability_Set_by_Month (PLN_BEN_SET_MDL_SYS_ID, Begin_Dt)
--22542396 on 8/19/2015
