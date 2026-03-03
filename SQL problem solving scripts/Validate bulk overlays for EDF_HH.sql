CREATE OR REPLACE PROCEDURE EDF_HH.SP_VALIDATE_LIVE_DATA (p_type NUMBER)  IS
-- Purpose:        To validate overlay data during bulk overlay load. All rejections end up
--                 in table: HH_EDF_OLAY_LOAD_REJECT.
--                 Procedure can validate both file types
-- Created by:     Csaba Riedlinger
-- Date:           04/09/2008
-- Change history: 

l_err_msg    VARCHAR2 (2000) ; -- Error message

BEGIN

    CASE p_type 
    WHEN 1 THEN -- When file contains 365x50 overlay values per MPAN-Quote

        -- Get rid of any duplicates. MPAN_CORE - QUOTE_ID - CONS_DATE combination must be unique!
        DELETE FROM HH_EDF_OLAY_LOAD_TEMPL a
        WHERE rowid in (SELECT rowid 
                        FROM   (SELECT a.mpan_core, a.quote_id, a.cons_date,
                                       row_number () over (partition by mpan_core, quote_id, cons_date order by mpan_core, quote_id, cons_date) as rn
                                FROM   HH_EDF_OLAY_LOAD_TEMPL a)
                        WHERE  rn <> 1) ;      

        COMMIT ;

        -- Do validation checks
        -- Clear up exception table first
        EXECUTE IMMEDIATE 'TRUNCATE table HH_EDF_OLAY_LOAD_REJECT' ;

        -- Spring CC test: HH47 - HH50 must not have a value except on Spring clock change day
        insert into HH_EDF_OLAY_LOAD_REJECT (MPAN_CORE, QUOTE_ID, CONS_DATE, ERROR_DESC)
        select distinct a.mpan_core, quote_id, cons_date, 'Spring CC data issue' as error_desc
        from   hh_edf_olay_load_templ a,
               (select * from finance.df_special_day_onoff b where substr (df_special_day, 1, 4) = 'DT11') b 
        where  b.dfdate = a.cons_date
               AND (nvl (a.VAL_47, 0) <> 0 OR nvl (a.VAL_48, 0) <> 0 OR nvl (a.VAL_49, 0) <> 0 OR nvl (a.VAL_50, 0) <> 0) ;

        -- Autumn CC test: both HH49 and HH50 must have a value on Autumn clock change day  
        insert into HH_EDF_OLAY_LOAD_REJECT (MPAN_CORE, QUOTE_ID, CONS_DATE, ERROR_DESC)
        select distinct a.mpan_core, quote_id, cons_date, 'October CC data issue' as error_desc
        from   hh_edf_olay_load_templ a, 
               (select * from finance.df_special_day_onoff b where substr (df_special_day, 1, 4) = 'DT14') b 
        where  b.dfdate = a.cons_date
               AND (nvl (a.VAL_49, 0) = 0 OR nvl (a.VAL_50, 0) = 0) ;

        -- HH49 and HH50 can only have a value on Autumn clock change day  
        insert into HH_EDF_OLAY_LOAD_REJECT (MPAN_CORE, QUOTE_ID, CONS_DATE, ERROR_DESC)
        select distinct a.mpan_core, quote_id, cons_date, 'HH49/HH50 data issue' as error_desc
        from   hh_edf_olay_load_templ a 
        where  a.cons_date NOT in (select b.dfdate from finance.df_special_day_onoff b where substr (df_special_day, 1, 4) = 'DT14')
               AND (nvl (a.VAL_49, 0) > 0 OR nvl (a.VAL_50, 0) > 0) ;

        -- MPAN_CORE and Quote combinations that do not exist
        insert into HH_EDF_OLAY_LOAD_REJECT (MPAN_CORE, QUOTE_ID, CONS_DATE, ERROR_DESC)
        select mpan_core, quote_id, null as cons_date, 'Invalid MPAN - Quote combination' as error_desc 
        from   (select distinct mpan_core, quote_id 
               from   hh_edf_olay_load_templ a 
               where  quote_id is not null) a
        where not exists (select null 
                          from   hh_edf_contract_summary b 
                          where  b.mpan_id = a.mpan_core 
                                 AND b.quote_id = a.quote_id)
              AND quote_id is not null ;

        -- MPAN_CORE and Quote combinations with gaps in cons_date 
        insert into HH_EDF_OLAY_LOAD_REJECT (MPAN_CORE, QUOTE_ID, CONS_DATE, ERROR_DESC)   
        select mpan_core, quote_id, day, 'Gaps in overlay consumption data' as error_desc
        from (select d.mpan_core, d.quote_id, d.day, a.cons_date 
              from   (SELECT MPAN_CORE, QUOTE_ID, min (CONS_DATE) as MIN_DATE, max (CONS_DATE) as MAX_DATE
                      FROM   HH_EDF_OLAY_LOAD_TEMPL
                      GROUP BY MPAN_CORE, QUOTE_ID) b,
                     hh_edf_olay_load_templ a  
                     RIGHT OUTER JOIN
                     (SELECT d.DAY, c.MPAN_CORE, c.QUOTE_ID 
                      FROM VW_TIME_DIM d, 
                           (SELECT distinct MPAN_CORE, QUOTE_ID 
                            FROM HH_EDF_OLAY_LOAD_TEMPL c) c) d
              ON     a.CONS_DATE = d.DAY
              WHERE  a.MPAN_CORE = b.MPAN_CORE
                     AND a.MPAN_CORE = d.MPAN_CORE
                     AND a.QUOTE_ID = b.QUOTE_ID
                     AND a.QUOTE_ID = d.QUOTE_ID
                     AND a.CONS_DATE BETWEEN b.MIN_DATE AND b.MAX_DATE)
        where CONS_DATE is NULL ;     
 
    WHEN 2 THEN -- When file contains MPAN-Quote tuples only and data comes from metered data
  
        -- Clear up exception table first
        EXECUTE IMMEDIATE 'TRUNCATE table HH_EDF_OLAY_LOAD_REJECT' ;

        -- MPAN_CORE and Quote combinations that do not exist
        insert into HH_EDF_OLAY_LOAD_REJECT (MPAN_CORE, QUOTE_ID, CONS_DATE, ERROR_DESC)
        select mpan_core, quote_id, null as cons_date, 'Invalid MPAN - Quote combination' as error_desc 
        from   (select distinct mpan_core, quote_id 
               from   hh_edf_olay_load_templ a 
               where  quote_id is not null) a
        where not exists (select null 
                          from   hh_edf_contract_summary b 
                          where  b.mpan_id = a.mpan_core 
                                 AND b.quote_id = a.quote_id)
              AND quote_id is not null ;

        -- MPAN_CORE and Quote combinations with not enough metered data
        insert into HH_EDF_OLAY_LOAD_REJECT (MPAN_CORE, QUOTE_ID, CONS_DATE, ERROR_DESC)
        SELECT b.MPAN_CORE, c.QUOTE_ID, null as CONS_DATE, 'Not enough metered data available' as error_desc 
        FROM   HH_EDF_METERED_CONS_AVAIL b,
               HH_EDF_OLAY_LOAD_TEMPL c
        WHERE  b.MPAN_CORE = c.MPAN_CORE
               AND b.MPAN_CORE = c.MPAN_CORE
               AND b.END_DATE - b.REAL_START_DATE < 365 ;

        -- MPAN_CORE and Quote combinations with gaps in cons_date 
        insert into HH_EDF_OLAY_LOAD_REJECT (MPAN_CORE, QUOTE_ID, CONS_DATE, ERROR_DESC)
        select mpan_core, quote_id, day, 'Gaps in metered data' as error_desc
        from   (SELECT d.MPAN_CORE, d.QUOTE_ID, d.DAY, A.SETTLEMENT_DATE  
               FROM   HH_EDF_METERED_CONS_AVAIL b,
                      HH_EDF_OLAY_LOAD_TEMPL c,
                      HH_EDF_METERED_CONS a
                      RIGHT OUTER JOIN
                      (SELECT d.DAY, c.MPAN_CORE, c.QUOTE_ID 
                       FROM VW_TIME_DIM d, 
                            (SELECT distinct MPAN_CORE, QUOTE_ID 
                             FROM HH_EDF_OLAY_LOAD_TEMPL c) c) d
               ON     a.SETTLEMENT_DATE = d.DAY                      
               WHERE  a.MPAN_ID = b.MPAN_CORE
                      AND a.MPAN_ID = c.MPAN_CORE
                      AND c.QUOTE_ID = d.QUOTE_ID
                      AND a.SETTLEMENT_DATE between b.end_date - 365 and b.END_DATE)
        where   SETTLEMENT_DATE is NULL ;
        
    END CASE ;

    COMMIT ;

    -- Exception handler
EXCEPTION
    WHEN OTHERS THEN
         l_err_msg := SQLCODE || ' ' || SQLERRM ;
         ROLLBACK ;
         RAISE ;

END SP_VALIDATE_LIVE_DATA ;
/
