/*
use Galaxy_Research
go

select count(*) from Galaxy_Research.dbo.Member_Coverage_Month_20150331			--114782228
select count(*) from Galaxy_Research.dbo.Customer_Segment_Coverage_20150331		--1760364
select count(*) from Galaxy_Research.dbo.Plan_Benefit_Set_Model_20150331		--585458
select count(*) from Galaxy_Research.dbo.Plan_Benefit_Set_Liability_20150331	--2383990
select count(*) from Galaxy_Research.dbo.Customer_Segment_Plan_Benefit_20150331	--2670383
select count(*) from Galaxy_Research.dbo.Plan_Benefit_Service_20150331			--2088037
select count(*) from Galaxy_Research.dbo.Benefit_Liability_Type_20150331		--6
select count(*) from Galaxy_Research..Service_Event_20150331					--35
*/

--Row Count: 688,146,986 Last Verified on 2014/09/04 
select
	MBR_SYS_ID, 
	Cust_Seg_Nbr,
	Cust_Seg_Sys_Id, 
	MED_PRDCT_1_CD, 
	PLN_VAR_SUBDIV_CD, 
	RPT_CD_BR_CD, 
	MBR_COV_MO_ROW_EFF_DT,
	MBR_COV_MO_ROW_END_DT,
	UPDT_DT
from Member_Coverage_Month	a
where med_cov_ind			= 'Y'	--only interested in members with medical coverage
	and PLN_VAR_SUBDIV_CD	<> ''	--No information in plan benefits for these
	and year(MBR_COV_MO_ROW_END_DT) >= 2011

--Row Count: 26,577,231 Last Verified on 2014/09/04 
select 
	Cust_Seg_Nbr,
	cust_seg_sys_id,
	prdct_cd,
	pln_var_subdiv_cd,
	rpt_cd_br_cd,
	CUST_SEG_COV_ROW_EFF_DT,
	CUST_SEG_COV_ROW_END_DT,
	CUST_DRVN_HLTH_PLN_CD,
	UPDT_DT
from Customer_Segment_Coverage
where year(csc.CUST_SEG_COV_ROW_END_DT) >=	2011
	and csc.COV_TYP_CD					=	'M'	

--Row Count: 5,606,070 Last Verified on 2014/09/04 
select 
	cust_seg_sys_id,
	prdct_cd,
	pln_var_subdiv_cd,
	rpt_cd_br_cd,
	CUST_SEG_PLN_BEN_EFF_DT,
	CUST_SEG_PLN_BEN_END_DT,
	PLN_BEN_SET_MDL_SYS_ID,
	COV_TYP_GRP_CD,
	MDL_PLN_NBR,
	MDL_POL_NBR,
	UPDT_DT
from Customer_Segment_Plan_Benefit
where year(CUST_SEG_PLN_BEN_END_DT) >= 2011

--Row Count: 691,653 Last Verified on 2014/09/04 
select
	PLN_BEN_SET_MDL_SYS_ID,
	PLN_BEN_SET_MDL_ROW_EFF_DT,
	PLN_BEN_SET_MDL_ROW_END_DT,
	MDL_PLN_NBR, 
	MDL_POL_NBR, 
	SRC_SYS_CD, 
	SRC_SYS_GRP_CD, 
	COV_TYP_CD, 
	FINC_ARNG_CD, 
	PLN_INFO_RPTBL_IND, 
	PLN_YR_TXT, 
	PRDCT_CD, 
	RISK_CLSS_TXT,
	UPDT_DT
from Plan_Benefit_Set_Model 
where year(PLN_BEN_SET_MDL_ROW_END_DT) >= 2011

--Row Count: 30,987,112 Last Verified on 2014/09/04 
select 
	PLN_BEN_SET_MDL_SYS_ID, 
	PLN_BEN_SRVC_ROW_EFF_DT,	
	PLN_BEN_SRVC_ROW_END_DT, 
	SRVC_EVNT_ID, 
	BEN_COINS_PCT, 
	BEN_COINS_BAS_TXT, 
	BEN_COPAY_AMT, 
	BEN_COPAY_BAS_TXT,
	Updt_Dt
from Plan_Benefit_Service
where Srvc_Evnt_ID			in		(254,835,1611,105)						--only interested in 4 main types of services
	and	IN_OUT_NTWK_CD		=		'I'										--In Network Only
	--excluding oddball stuff; these last two filters exclude <7% of rows
	and BEN_COINS_BAS_TXT	=	'OF ELIGIBLE EXPENSES'						--Includes covered services
	and (BEN_COPAY_AMT	= 0 
		or	 ben_coins_pct = 100)											--Exclude services with both copay and coins
	and year(PLN_BEN_SRVC_ROW_END_DT) >= 2011

--Row Count: 35 Last Verified on 2014/09/04 
select *
from Service_Event

--Row Count: 6,505,559 Last Verified on 2014/09/04 
select *
from Plan_Benefit_Set_Liability
where year(PLN_BEN_SET_LIAB_ROW_END_DT) >= 2011
	and	IN_OUT_NTWK_CD		=		'I'

--Row Count: 6 Last Verified on 2014/09/04 
select *
from BENEFIT_LIABILITY_TYPE

--Row Count: 12 Last Verified on 2015/05/11 
select *
from Customer_Driven_Health_Plan_Code

--Row Count: 8,679,813 Last Verified on 2014/09/04 
select 
	CONTR_PLN_COV_SYS_ID,
	CUST_SEG_GRP_ID,
	PAR_CUST_SYS_ID,
	CUST_PLN_ID,   
    CUST_SEG_SYS_ID,  
    CONTR_PLN_COV_ROW_EFF_DT,  
    CONTR_PLN_COV_ROW_END_DT,
	METALLIC_LVL,
	CERT_OF_COV_FL_YR,
	GRANDFATHERED_PLAN_STATUS,
	HSA_HRA_MINIMUM_CONTRIBUTION,
	HSA_HRA_MAXIMUM_CONTRIBUTION,
	UPDT_DT
from CONTRACT_PLAN_COVERAGE 
where year(CONTR_PLN_COV_ROW_END_DT) >= 2011

--Row Count: 10,198,092 Last Verified on 2014/09/04 
select 
	CONTR_PLN_COV_SYS_ID,
	CUST_SEG_GRP_ID,
	PAR_CUST_SYS_ID,
	CUST_PLN_ID,
	CUST_SEG_SYS_ID,
	CUST_SEG_GRP_STRCT_ROW_EFF_DT,
	CUST_SEG_GRP_STRCT_ROW_END_DT,
	PLN_VAR_SUBDIV_CD,
    PRDCT_CD,  
    RPT_CD_BR_CD,
	UPDT_DT
from CUSTOMER_SEGMENT_GROUP_STRUCTURE
where year(CUST_SEG_GRP_STRCT_ROW_END_DT) >= 2011

