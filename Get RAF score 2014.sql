--drop table udb_ctheis..RA_2014_Demo

select distinct
	UniqueMemberID	=	INDV_SYS_ID, 
	GenderCd		=	Gdr_Cd, 
	BirthDate		=	cast(2015-Age as char(4))+'0701',
	AgeLast			=	Age
into udb_ctheis..RA_2014_Demo
from ##PlanBenefitYear
where PlanYear	= 2014

create unique clustered index ucix_Ind on udb_ctheis..RA_2014_Demo (UniqueMemberID);

--drop table udb_ctheis..RA_2014_Diag;

with a as (
	select fc.Indv_Sys_Id, d.FULL_DT, 
		D1	=	dc1.DIAG_CD, 
		D2	=	dc2.DIAG_CD,
		D3	=	dc3.DIAG_CD
	from MiniHPDM..Fact_Claims			fc
	join MiniHPDM..Dim_Date				d	on	fc.Dt_Sys_Id		=	d.DT_SYS_ID
	join MiniHPDM..Dim_Diagnosis_Code	dc1	on	fc.Diag_1_Cd_Sys_Id	=	dc1.DIAG_CD_SYS_ID
	join MiniHPDM..Dim_Diagnosis_Code	dc2	on	fc.Diag_2_Cd_Sys_Id	=	dc2.DIAG_CD_SYS_ID
	join MiniHPDM..Dim_Diagnosis_Code	dc3	on	fc.Diag_3_Cd_Sys_Id	=	dc3.DIAG_CD_SYS_ID
	join udb_ctheis..RA_2014_Demo		i	on	fc.Indv_Sys_Id		=	i.UniqueMemberID
	where d.YEAR_NBR	=	2014
	)
select UniqueMemberID, ICDCd, 
	DiagnosisServiceDate	=	min(Full_DT)
into udb_ctheis..RA_2014_Diag
from (
	select 
		UniqueMemberID	=	Indv_Sys_Id, 
		ICDCd			=	D1, 
		FULL_DT
	from a
	union
	select Indv_Sys_Id, D2, FULL_DT
	from a
	union
	select Indv_Sys_Id, D3, FULL_DT
	from a
	)	a
group by UniqueMemberID, ICDCd


exec RA_Commercial_2014..spRAFDiagInput 'udb_ctheis..RA_2014_Demo','udb_ctheis..RA_2014_Diag','udb_ctheis','2014'