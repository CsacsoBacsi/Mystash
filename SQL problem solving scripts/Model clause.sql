CREATE OR REPLACE PROCEDURE sp_publish_edf_nhh_output (scenario IN varchar2) AS
    start_date_raw  varchar2 (20) ;
    end_date_raw    varchar2 (20) ;      
    startDate       date ;
    endDate         date ;
    numdays         number ;
    tmp             varchar2 (4000) ;
BEGIN              
        dbms_aw.execute('AW ATTACH EDF_NHH_OUTPUT_AW.EDF_NHH_OUTPUT');
        
        -- Limit Levels to avoid having to bring them back in the view
        sp_limit_dim_to_level('TIME','DAY') ;
        sp_limit_dim_to_level('HALF_HOUR' ,'BASE') ;
        sp_limit_dim_to_level('GSP_GROUP_ID' ,'BASE') ;
        sp_limit_dim_to_level('ELEC_LICENCE' ,'BASE') ;
        sp_limit_dim_to_level('PROFILE_CLASS' ,'BASE') ;				
        sp_limit_dim_to_level('BUSINESS_STRUCTURE' ,'SECTOR') ;
    
        dbms_aw.execute('LMT NHH_OUTPUT_SC TO '''|| scenario ||'''') ;
        dbms_aw.execute('CALL COPY_PARTITION_COMPOSITE (''NHH_OUTPUT_PRT_COMPOSITE'' ''NHH_OUTPUT_PARTITION_TEMPLATE'')') ;

        dbms_aw.execute('LMT NHH_OUTPUT_VER TO NHH_OUTPUT_SC.NHH_OUTPUT_VER') ;        
        dbms_aw.run('shw NHH_OUTPUT_VER_FORECAST_START_DATE', start_date_raw) ;
        dbms_aw.run('shw NHH_OUTPUT_VER_FORECAST_END_DATE', end_date_raw) ;
        
        startDate := to_date (start_date_raw, 'MM/DD/YYYY') ;
        endDate   := to_date (end_date_raw, 'MM/DD/YYYY') ;  
   
        numdays := endDate - startDate ;
        
        for i in 0 .. numdays
        loop
            dbms_aw.execute ('LMT TIME TO ''' || to_char (startDate + i, 'MM/DD/YYYY') ||'''') ;
            dbms_aw.run ('shw TIME', tmp) ;
           
            INSERT /*+ APPEND NOLOGGING */ INTO NHH_EDF_OUTPUT_OR
                (TIME_ID, HALF_HOUR, GSP_GROUP_ID, ELEC_LICENCE, PROFILE_CLASS, BUSINESS_STRUCTURE, NHH_OUTPUT_SC,
				 S_SCALED_CORRECTED, S_SCALED_CORRECTED_CT, S_SCALED_CORRECTED_GSP, S_SCALED_CORRECTED_NBP)
            SELECT
                 to_date (TIME_ID,'MM/DD/YYYY') as TIME_ID, 
				 HALF_HOUR, 
				 GSP_GROUP_ID,
				 ELEC_LICENCE,
				 PROFILE_CLASS,
				 BUSINESS_STRUCTURE,
				 NHH_OUTPUT_SC,
				 S_SCALED_CORRECTED,
				 S_SCALED_CORRECTED_CT,
				 S_SCALED_CORRECTED_GSP,
				 S_SCALED_CORRECTED_NBP
            FROM
                VW_NHH_OUTPUT_SC_N_WB
            WHERE
                NHH_OUTPUT_SC = scenario ;
                
            COMMIT ;
            
        END LOOP ;

        dbms_aw.execute('AW DETACH EDF_NHH_OUTPUT_AW.EDF_NHH_OUTPUT');
END ;

CREATE OR REPLACE VIEW VW_NHH_OUTPUT_SC_N_WB
(TIME_ID, HALF_HOUR, GSP_GROUP_ID, ELEC_LICENCE, PROFILE_CLASS, BUSINESS_STRUCTURE, NHH_OUTPUT_SC, S_SCALED_CORRECTED, S_SCALED_CORRECTED_CT, S_SCALED_CORRECTED_GSP, S_SCALED_CORRECTED_NBP)
AS 
SELECT
--
--  Change History
--
-- Date      Author             Description
-- ========  =================  ================================================
-- 13/09/07  Csaba Riedlinger   Created 
--                              
--                              
--
TIME_ID, HALF_HOUR, GSP_GROUP_ID, ELEC_LICENCE, PROFILE_CLASS, BUSINESS_STRUCTURE, NHH_OUTPUT_SC, S_SCALED_CORRECTED, S_SCALED_CORRECTED_CT, S_SCALED_CORRECTED_GSP, S_SCALED_CORRECTED_NBP 
FROM    TABLE (olap_table ('EDF_NHH_OUTPUT_AW.EDF_NHH_OUTPUT DURATION SESSION', '', '',
                         'DIMENSION time_id from TIME ' ||
                         'DIMENSION half_hour from HALF_HOUR ' ||						 
                         'DIMENSION gsp_group_id from GSP_GROUP_ID ' ||
                         'DIMENSION elec_licence from ELEC_LICENCE ' ||
                         'DIMENSION profile_class from PROFILE_CLASS ' ||
                         'DIMENSION business_structure from BUSINESS_STRUCTURE ' ||
                         'DIMENSION nhh_output_sc from NHH_OUTPUT_SC ' ||						 						 
                         'MEASURE s_scaled_corrected from NHH_OUTPUT_SC_N_OV_S_SCALED_CORRECTED ' ||
                         'MEASURE s_scaled_corrected_ct from NHH_OUTPUT_SC_N_OV_S_SCALED_CORRECTED_CT ' ||
                         'MEASURE s_scaled_corrected_gsp from NHH_OUTPUT_SC_N_OV_S_SCALED_CORRECTED_GSP ' ||
                         'MEASURE s_scaled_corrected_nbp from NHH_OUTPUT_SC_N_OV_S_SCALED_CORRECTED_NBP ' ||		 						 						 						 						 						 						 
                         'LOOP NHH_OUTPUT_PRT_COMPOSITE'))
where  s_scaled_corrected is not null
or     s_scaled_corrected_ct is not null
or     s_scaled_corrected_gsp is not null
or     s_scaled_corrected_nbp is not null
model   dimension by (time_id,
                      half_hour,
                      gsp_group_id,
                      elec_licence,
					  profile_class,
					  business_structure,
                      nhh_output_sc)
        measures     (s_scaled_corrected,
					  s_scaled_corrected_ct,
					  s_scaled_corrected_gsp,
					  s_scaled_corrected_nbp)
rules update sequential order ()
/

call sp_publish_edf_nhh_output ('N022') ;	

call SP_PUBLISH_TLM ('T033') ;

select count (*) from tlm_output ;

select systimestamp from dual ;

call dbms_aw.execute('AW DETACH EDF_NHH_AW.EDF_NHH');

call dbms_aw.execute('AW DETACH EDF_NHH_OUTPUT_AW.EDF_NHH_OUTPUT');

grant select on VW_GSP_BMU_SC_VW_WB to edf_nhh_aw ;

drop table NHH_EDF_OUTPUT_OR ;

CREATE TABLE NHH_EDF_OUTPUT_OR
(
  TIME_ID                 DATE,
  HALF_HOUR               VARCHAR2(2 BYTE),
  GSP_GROUP_ID            VARCHAR2(2 BYTE),
  ELEC_LICENCE            VARCHAR2(10 BYTE),
  PROFILE_CLASS           VARCHAR2(5 BYTE),
  BUSINESS_STRUCTURE      VARCHAR2(10 BYTE),
  NHH_OUTPUT_SC           VARCHAR2(20 BYTE),
  S_SCALED_CORRECTED      NUMBER,
  S_SCALED_CORRECTED_CT   NUMBER,
  S_SCALED_CORRECTED_GSP  NUMBER,
  S_SCALED_CORRECTED_NBP  NUMBER
)
TABLESPACE FINANCE_SCHEMA
PCTUSED    0
PCTFREE    10
INITRANS   1
MAXTRANS   255
PARTITION BY LIST (NHH_OUTPUT_SC) 
(  
  PARTITION PINITIAL VALUES ('0')  
) ;
  
  
create or replace PROCEDURE sp_add_partition (p_table_name VARCHAR2, p_part_value VARCHAR2) IS
-- Adds a partition to the table specified as the first parameter
-- The partition name is 'P' + partition value

l_err_msg VARCHAR2 (1000) ;

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE ' || p_table_name || ' add partition P' || p_part_value || ' VALUES (''' || p_part_value || ''')' ; 

    -- Exception handling    
    EXCEPTION
       WHEN OTHERS THEN
           l_err_msg := SQLCODE || ' ' || SQLERRM ;
           dbms_output.put_line (l_err_msg) ;             
           RAISE ;
          
END sp_add_partition ;

with t1 as (
     select   a.time_id,
              a.half_hour,
              a.scenario_id as nhh_output_sc,
			  d.proposition_id as elec_product, -- Proposition level
              b.sector as business_structure,
	          b.gsp_group_id,
              b.elec_licence,
			  b.profile_class,
--            c.tpr,
--			  c.ssc,
--			  c.llf
              SUM (S_SCALED_CORRECTED_NBP) as S_SCALED_CORRECTED_NBP
     from     nhh_edf_pub a,
	          edf_nhh_output_key b,
--			  edf_nhh_sett_key c,
              elec_product_dim d -- Contains the VERSION - PROPOSITION hierarchy
	 where    a.output_key_id = b.output_key_id
--	          AND a.sett_key_id = c.sett_key_id
              AND d.VERSION = a.VERSION	   
     group by a.time_id,
              a.half_hour,
			  a.scenario_id,
			  d.proposition_id,
              b.sector,
              b.gsp_group_id,
	          b.elec_licence,
			  b.profile_class
),
t2 as (
     select   t1.time_id,
              t1.half_hour,
              t1.business_structure,
              t2.bmu_id, -- Replaces elec_licence and gsp_group_id
              t1.elec_product, -- Proposition level
              t1.nhh_output_sc,
              SUM (t1.S_SCALED_CORRECTED_NBP) as S_SCALED_CORRECTED_NBP 
     from     t1,
              gsp_bmu_map t2
     where    t1.gsp_group_id = t2.gsp_group_id
              AND t1.elec_licence = t2.elec_licence
     group by time_id,
	          half_hour,
			  business_structure,
			  bmu_id,
			  elec_product,
			  nhh_output_sc
)
select time_id,
       half_hour,
       business_structure,
       bmu_id,
       elec_product,
       nhh_output_sc,
       S_SCALED_CORRECTED_NBP
from   t2

with t1 as (
     select   a.time_id,
              a.half_hour,
              a.scenario_id as nhh_output_sc,
			  a.proposition_id as elec_product, -- Already on proposition level
              b.sector as business_structure,
	          b.gsp_group_id,
              b.elec_licence,
			  b.profile_class,
--            c.tpr,
--			  c.ssc,
--			  c.llf
              SUM (S_SCALED_CORRECTED_NBP) as S_SCALED_CORRECTED_NBP
     from     nhh_edf_pub a,
	          edf_nhh_output_key b,
--			  edf_nhh_sett_key c,
--            elec_product_dim d -- Contains the VERSION - PROPOSITION hierarchy
	 where    a.output_key_id = b.output_key_id
--	          AND a.sett_key_id = c.sett_key_id
--            AND d.VERSION = a.VERSION	   
     group by a.time_id,
              a.half_hour,
			  a.scenario_id,
			  a.proposition_id,
              b.sector,
              b.gsp_group_id,
	          b.elec_licence,
			  b.profile_class
),
t2 as (
     select   t1.time_id,
              t1.half_hour,
              t1.business_structure,
              t2.bmu_id, -- Replaces elec_licence and gsp_group_id
              t1.elec_product,
              t1.nhh_output_sc,
              SUM (t1.S_SCALED_CORRECTED_NBP) as S_SCALED_CORRECTED_NBP 
     from     t1,
              gsp_bmu_map t2
     where    t1.gsp_group_id = t2.gsp_group_id
              AND t1.elec_licence = t2.elec_licence
     group by time_id,
	          half_hour,
			  business_structure,
			  bmu_id,
			  elec_product,
			  nhh_output_sc
)
select time_id,
       half_hour,
       business_structure,
       bmu_id,
       elec_product,
       nhh_output_sc,
       S_SCALED_CORRECTED_NBP
from   t2

select x.prop, t.bmu, sum (x.meas) as meas
from (select b.prop, a.gsp, a.pc, sum (a.meas) as meas
      from (select 1 as ver, 1 as gsp, 1 as pc, 15 as meas from dual
            union
            select 1 as ver, 2 as gsp, 1 as pc, 21 as meas from dual
            union
            select 2 as ver, 2 as gsp, 2 as pc, 3 as meas from dual
			union
			select 1 as ver, 2 as gsp, 2 as pc, 5 as meas from dual
            union
            select 2 as ver, 1 as gsp, 1 as pc, 4 as meas from dual) a,
            (select 1 as ver, 2 as prop from dual 
            union
            select 2 as ver, 2 as prop from dual) b
      where a.ver = b.ver
      group by b.prop, a.gsp, a.pc) x,
      (select 1 as gsp, 1 as pc, 1 as bmu from dual
      union
      select 2 as gsp, 1 as pc, 2 as bmu from dual
      union
      select 2 as gsp, 2 as pc, 3 as bmu from dual) t
where x.gsp = t.gsp
      AND x.pc = t.pc
group by x.prop, t.bmu

select prod, country, cyear, s from 
((select 'Prod A' as prod, 'Country A' as country, '2000' as cyear, 15 as sales from dual
union
select 'Prod A' as prod, 'Country B' as country, '2000' as cyear, 20 as sales from dual
union
select 'Prod B' as prod, 'Country A' as country, '2001' as cyear, 12 as sales from dual) t)
MODEL
PARTITION BY (country)
DIMENSION BY (prod, cyear)
MEASURES (sales s)
KEEP NAV
RULES UPSERT SEQUENTIAL ORDER 
(s ['Prod A', '2002'] = s ['Prod B', '2001'] * 5,
 s ['Prod B', cyear <= '2000'  ] = s ['Prod B', CV ()] * 6) ;

select prod, country, cyear, s from 
((select 'Prod A' as prod, 'Country A' as country, '2000' as cyear, 15 as sales from dual
union
select 'Prod A' as prod, 'Country B' as country, '2000' as cyear, 20 as sales from dual
union
select 'Prod B' as prod, 'Country A' as country, '2001' as cyear, 12 as sales from dual) t)
MODEL RETURN ALL ROWS
DIMENSION BY (prod, country, cyear)
MEASURES (sales s)
KEEP NAV
RULES UPSERT SEQUENTIAL ORDER 
(s ['Prod A', 'Country B', '2000'] = s ['Prod B', 'Country A', '2001'] * 5,
 s ['Prod B', 'Country A', '2000'] = s ['Prod A', 'Country A', CV ()] * 6,
 s ['TotalP', 'Total C', FOR cyear like '%' FROM '2000' to '2001' increment 1] = sum (s) [prod, country, cv ()],
 s ['Max P', 'Max C', 'Year'] = MAX (nvl (s, 0)) [prod, country, ANY]) ;

 
CREATE OR REPLACE VIEW VW_EDF_NHH_TLM_WB3
(GSP_GROUP_ID, HH_ID, TLM)
AS 
SELECT 
    GSP_GROUP_ID 
    ,HH_ID 
    ,TLM 
FROM (SELECT 
    GSP_GROUP_ID 
    ,HH_ID 
    ,TLM 
    FROM TABLE (OLAP_TABLE('EDF_NHH_AW.EDF_NHH DURATION SESSION' 
            ,'' 
            ,'' 
            ,'DIMENSION hh_id FROM half_hour ' ||
             'DIMENSION gsp_group_id FROM gsp_group_id ' ||     
             'DIMENSION tlm_sc_id FROM tlm_sc ' || 
             'MEASURE tlm FROM tlm_sc_vw_tlm ' 
            )) 
  WHERE tlm is not null 
        MODEL 
        DIMENSION BY (hh_id
                  ,gsp_group_id
                  ,tlm_sc_id 
        ) 
        MEASURES ( 
                  tlm 
        ) 
        RULES SEQUENTIAL ORDER () 
)
