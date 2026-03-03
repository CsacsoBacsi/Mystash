CREATE OR REPLACE PROCEDURE EDF_HH.SP_LOAD_BULK_OVERLAY (p_type NUMBER, p_user_comment VARCHAR2) IS
-- Purpose:        To create bulk overlays using user created XLS files. Two types of files supported:
--                 1. MPAN-Quote + 365x50 hh data
--                 2. MPAN-Quote combinations only
--                 The files are first loaded into a template table
-- Created by:     Csaba Riedlinger
-- Date:           04/09/2008
-- Change history: 

l_mpan_quote VARCHAR2 (250) := '-1:-1' ;
l_nextval    NUMBER ;
l_sum        NUMBER ;
l_olay_part  VARCHAR2 (30) ;
l_min_date   DATE ;
l_max_date   DATE ;
l_no_cont    VARCHAR2 (1) ;
l_err_msg    VARCHAR2 (2000) ;

-- Cursor to loop over each and every row of the template table (MPAN-Quote combinations)
CURSOR c1 IS SELECT a.MPAN_ID as MPAN_CORE, c.QUOTE_ID, SETTLEMENT_DATE,
                    a.PERIOD_METERED_CONS_1 as VAL_1, a.PERIOD_METERED_CONS_2 as VAL_2, a.PERIOD_METERED_CONS_3 as VAL_3, a.PERIOD_METERED_CONS_4 as VAL_4, a.PERIOD_METERED_CONS_5 as VAL_5,
                    a.PERIOD_METERED_CONS_6 as VAL_6, a.PERIOD_METERED_CONS_7 as VAL_7, a.PERIOD_METERED_CONS_8 as VAL_8, a.PERIOD_METERED_CONS_9 as VAL_9, a.PERIOD_METERED_CONS_10 as VAL_10,
                    a.PERIOD_METERED_CONS_11 as VAL_11, a.PERIOD_METERED_CONS_12 as VAL_12, a.PERIOD_METERED_CONS_13 as VAL_13, a.PERIOD_METERED_CONS_14 as VAL_14, a.PERIOD_METERED_CONS_15 as VAL_15,
                    a.PERIOD_METERED_CONS_16 as VAL_16, a.PERIOD_METERED_CONS_17 as VAL_17, a.PERIOD_METERED_CONS_18 as VAL_18, a.PERIOD_METERED_CONS_19 as VAL_19, a.PERIOD_METERED_CONS_20 as VAL_20,
                    a.PERIOD_METERED_CONS_21 as VAL_21, a.PERIOD_METERED_CONS_22 as VAL_22, a.PERIOD_METERED_CONS_23 as VAL_23, a.PERIOD_METERED_CONS_24 as VAL_24, a.PERIOD_METERED_CONS_25 as VAL_25,
                    a.PERIOD_METERED_CONS_26 as VAL_26, a.PERIOD_METERED_CONS_27 as VAL_27, a.PERIOD_METERED_CONS_28 as VAL_28, a.PERIOD_METERED_CONS_29 as VAL_29, a.PERIOD_METERED_CONS_30 as VAL_30,
                    a.PERIOD_METERED_CONS_31 as VAL_31, a.PERIOD_METERED_CONS_32 as VAL_32, a.PERIOD_METERED_CONS_33 as VAL_33, a.PERIOD_METERED_CONS_34 as VAL_34, a.PERIOD_METERED_CONS_35 as VAL_35,
                    a.PERIOD_METERED_CONS_36 as VAL_36, a.PERIOD_METERED_CONS_37 as VAL_37, a.PERIOD_METERED_CONS_38 as VAL_38, a.PERIOD_METERED_CONS_39 as VAL_39, a.PERIOD_METERED_CONS_40 as VAL_40,
                    a.PERIOD_METERED_CONS_41 as VAL_41, a.PERIOD_METERED_CONS_42 as VAL_42, a.PERIOD_METERED_CONS_43 as VAL_43, a.PERIOD_METERED_CONS_44 as VAL_44, a.PERIOD_METERED_CONS_45 as VAL_45,
                    a.PERIOD_METERED_CONS_46 as VAL_46, a.PERIOD_METERED_CONS_47 as VAL_47, a.PERIOD_METERED_CONS_48 as VAL_48, a.PERIOD_METERED_CONS_49 as VAL_49, a.PERIOD_METERED_CONS_50 as VAL_50
             FROM   HH_EDF_METERED_CONS a,
                    HH_EDF_METERED_CONS_AVAIL b,
                    HH_EDF_OLAY_LOAD_TEMPL c
             WHERE  a.MPAN_ID = b.MPAN_CORE
                    AND a.MPAN_ID = c.MPAN_CORE
                    AND a.SETTLEMENT_DATE between b.end_date - 365 and b.END_DATE
                    AND NOT EXISTS (SELECT null 
                                    FROM HH_EDF_OLAY_LOAD_REJECT d 
                                    WHERE d.MPAN_CORE = c.MPAN_CORE AND nvl (d.QUOTE_ID, -999999) = nvl (c.QUOTE_ID, -999999))
                    ORDER BY a.MPAN_ID asc, c.QUOTE_ID asc, a.SETTLEMENT_DATE ;

-- Cursor to loop over each and every row of the template table (MPAN-Quote + 365x50 data)
CURSOR c2 IS SELECT * 
             FROM   HH_EDF_OLAY_LOAD_TEMPL a
             WHERE  NOT EXISTS (SELECT null 
                                FROM HH_EDF_OLAY_LOAD_REJECT b 
                                WHERE b.MPAN_CORE = a.MPAN_CORE AND nvl (b.QUOTE_ID, -999999) = nvl (a.QUOTE_ID, -999999))
             ORDER BY MPAN_CORE asc, QUOTE_ID asc, CONS_DATE asc ;

-- Cursor to fetch header row for a particular MPAN and Quote combination 
CURSOR c3 (p_mpan NUMBER, p_quote_id NUMBER)
          IS SELECT h.VERSION
             FROM   HH_EDF_CONT_CONS_OLAY_HEADER h
             WHERE  h.MPAN_CORE = p_mpan
                    AND nvl (h.QUOTE_ID, -999999) = nvl (p_quote_id, -999999) ;             

BEGIN

    CASE p_type 
    WHEN 1 THEN -- 365x50 hh data 

        -- Main loop
        FOR c2_rec IN c2 LOOP

            -- Test if we are dealing with a new MPAN - Quote combination 
            IF to_char (c2_rec.MPAN_CORE) || ':' || to_char (nvl (c2_rec.QUOTE_ID, '-1')) <> l_mpan_quote THEN
                l_mpan_quote := to_char (c2_rec.MPAN_CORE) || ':' || to_char (nvl (c2_rec.QUOTE_ID, '-1')) ;

                -- Delete existing partition, add new partition to detail table
                FOR c3_rec IN c3 (c2_rec.MPAN_CORE, c2_rec.QUOTE_ID) LOOP
                    HH_EDF_COMMON.sp_del_partition ('HH_EDF_CONT_CONS_OLAY', c3_rec.VERSION) ;
                END LOOP ;          
                SELECT HH_EDF_OVERLAY_SEQ.NEXTVAL INTO l_nextval FROM dual ;
                HH_EDF_COMMON.sp_add_partition ('HH_EDF_CONT_CONS_OLAY', l_nextval) ;
            
                -- Delete existing header info, add new row
                DELETE HH_EDF_CONT_CONS_OLAY_HEADER h
                WHERE  h.MPAN_CORE = c2_rec.MPAN_CORE 
                       AND nvl (h.QUOTE_ID, -999999) = nvl (c2_rec.QUOTE_ID, -999999) ;

                IF c2_rec.QUOTE_ID is null THEN
                    l_no_cont := 'Y' ;
                ELSE
                    l_no_cont := 'N' ;   
                END IF ;

                SELECT min (CONS_DATE), max (CONS_DATE) 
                       INTO l_min_date, l_max_date
                FROM   HH_EDF_OLAY_LOAD_TEMPL a
                WHERE  a.MPAN_CORE = c2_rec.MPAN_CORE
                       AND nvl (a.QUOTE_ID, -999999) = nvl (c2_rec.QUOTE_ID, -999999) ;

                INSERT INTO HH_EDF_CONT_CONS_OLAY_HEADER a
                       (mpan_core, date_from, date_to, quote_id, version, user_comment, NO_CONTRACT, created_user)
                       VALUES (c2_rec.MPAN_CORE, l_min_date, l_max_date, c2_rec.QUOTE_ID, l_nextval, p_user_comment, l_no_cont, 'M7038') ;
            END IF ;

            -- Calculate daily total value
            l_sum := nvl (c2_rec.VAL_1, 0) + nvl (c2_rec.VAL_2, 0) + nvl (c2_rec.VAL_3, 0) + nvl (c2_rec.VAL_4, 0) + nvl (c2_rec.VAL_5, 0) + nvl (c2_rec.VAL_6, 0) + 
                     nvl (c2_rec.VAL_7, 0) + nvl (c2_rec.VAL_8, 0) + nvl (c2_rec.VAL_9, 0) + nvl (c2_rec.VAL_10, 0) + nvl (c2_rec.VAL_11, 0) + nvl (c2_rec.VAL_12, 0) + 
                     nvl (c2_rec.VAL_13, 0) + nvl (c2_rec.VAL_14, 0) + nvl (c2_rec.VAL_15, 0) + nvl (c2_rec.VAL_16, 0) + nvl (c2_rec.VAL_17, 0) + nvl (c2_rec.VAL_18, 0) + 
                     nvl (c2_rec.VAL_19, 0) + nvl (c2_rec.VAL_20, 0) + nvl (c2_rec.VAL_21, 0) + nvl (c2_rec.VAL_22, 0) + nvl (c2_rec.VAL_23, 0) + nvl (c2_rec.VAL_24, 0) + 
                     nvl (c2_rec.VAL_25, 0) + nvl (c2_rec.VAL_26, 0) + nvl (c2_rec.VAL_27, 0) + nvl (c2_rec.VAL_28, 0) + nvl (c2_rec.VAL_29, 0) + nvl (c2_rec.VAL_30, 0) + 
                     nvl (c2_rec.VAL_31, 0) + nvl (c2_rec.VAL_32, 0) + nvl (c2_rec.VAL_33, 0) + nvl (c2_rec.VAL_34, 0) + nvl (c2_rec.VAL_35, 0) + nvl (c2_rec.VAL_36, 0) + 
                     nvl (c2_rec.VAL_37, 0) + nvl (c2_rec.VAL_38, 0) + nvl (c2_rec.VAL_39, 0) + nvl (c2_rec.VAL_40, 0) + nvl (c2_rec.VAL_41, 0) + nvl (c2_rec.VAL_42, 0) + 
                     nvl (c2_rec.VAL_43, 0) + nvl (c2_rec.VAL_44, 0) + nvl (c2_rec.VAL_45, 0) + nvl (c2_rec.VAL_46, 0) + nvl (c2_rec.VAL_47, 0) + nvl (c2_rec.VAL_48, 0) +
                     nvl (c2_rec.VAL_49, 0) + nvl (c2_rec.VAL_50, 0) ;

            INSERT INTO HH_EDF_CONT_CONS_OLAY
            (MPAN_CORE, CONS_DATE,
             VAL_1, VAL_2, VAL_3, VAL_4, VAL_5, VAL_6, VAL_7, VAL_8, VAL_9, VAL_10, VAL_11, VAL_12, VAL_13,
             VAL_14, VAL_15, VAL_16, VAL_17, VAL_18, VAL_19, VAL_20, VAL_21, VAL_22, VAL_23, VAL_24, VAL_25,
             VAL_26, VAL_27, VAL_28, VAL_29, VAL_30, VAL_31, VAL_32, VAL_33, VAL_34, VAL_35, VAL_36, VAL_37,
             VAL_38, VAL_39, VAL_40, VAL_41, VAL_42, VAL_43, VAL_44, VAL_45, VAL_46, VAL_47, VAL_48, VAL_49,
             VAL_50, DAY_TOTAL, OVERLAY_VERSION, EQU_DATE, QUOTE_ID, RN)
            VALUES (c2_rec.MPAN_CORE, c2_rec.CONS_DATE, 
                    c2_rec.VAL_1, c2_rec.VAL_2, c2_rec.VAL_3, c2_rec.VAL_4, c2_rec.VAL_5, c2_rec.VAL_6, c2_rec.VAL_7,
                    c2_rec.VAL_8, c2_rec.VAL_9, c2_rec.VAL_10, c2_rec.VAL_11, c2_rec.VAL_12, c2_rec.VAL_13, c2_rec.VAL_14,
                    c2_rec.VAL_15, c2_rec.VAL_16, c2_rec.VAL_17, c2_rec.VAL_18, c2_rec.VAL_19, c2_rec.VAL_20, c2_rec.VAL_21,
                    c2_rec.VAL_22, c2_rec.VAL_23, c2_rec.VAL_24, c2_rec.VAL_25, c2_rec.VAL_26, c2_rec.VAL_27, c2_rec.VAL_28,
                    c2_rec.VAL_29, c2_rec.VAL_30, c2_rec.VAL_31, c2_rec.VAL_32, c2_rec.VAL_33, c2_rec.VAL_34, c2_rec.VAL_35,
                    c2_rec.VAL_36, c2_rec.VAL_37, c2_rec.VAL_38, c2_rec.VAL_39, c2_rec.VAL_40, c2_rec.VAL_41, c2_rec.VAL_42,
                    c2_rec.VAL_43, c2_rec.VAL_44, c2_rec.VAL_45, c2_rec.VAL_46, c2_rec.VAL_47, c2_rec.VAL_48, c2_rec.VAL_49,
                    c2_rec.VAL_50, l_sum, to_char (l_nextval), NULL, c2_rec.QUOTE_ID, NULL) ;
 
        END LOOP ;
        
    WHEN 2 THEN -- Copy metered data

        FOR c1_rec IN c1 LOOP

            IF to_char (c1_rec.MPAN_CORE) || ':' || to_char (nvl (c1_rec.QUOTE_ID, '-1')) <> l_mpan_quote THEN
                l_mpan_quote := to_char (c1_rec.MPAN_CORE) || ':' || to_char (nvl (c1_rec.QUOTE_ID, '-1')) ;

                -- Delete existing partition, add new partition to detail table
                FOR c3_rec IN c3 (c1_rec.MPAN_CORE, c1_rec.QUOTE_ID) LOOP
                    HH_EDF_COMMON.sp_del_partition ('HH_EDF_CONT_CONS_OLAY', c3_rec.VERSION) ;
                END LOOP ;
                SELECT HH_EDF_OVERLAY_SEQ.NEXTVAL INTO l_nextval FROM dual ;
                HH_EDF_COMMON.sp_add_partition ('HH_EDF_CONT_CONS_OLAY', l_nextval) ;

                -- Delete existing header info, add new row
                DELETE HH_EDF_CONT_CONS_OLAY_HEADER h
                WHERE  h.MPAN_CORE = c1_rec.MPAN_CORE
                       AND nvl (h.QUOTE_ID, -999999) = nvl (c1_rec.QUOTE_ID, -999999) ;

                IF c1_rec.QUOTE_ID is null THEN
                    l_no_cont := 'Y' ;
                ELSE
                    l_no_cont := 'N' ;
                END IF ;

                SELECT end_date - 365, a.end_date
                       INTO l_min_date, l_max_date
                FROM   HH_EDF_METERED_CONS_AVAIL a
                WHERE  a.MPAN_CORE = c1_rec.MPAN_CORE ;

                INSERT INTO HH_EDF_CONT_CONS_OLAY_HEADER a
                       (mpan_core, date_from, date_to, quote_id, version, user_comment, NO_CONTRACT, created_user)
                       VALUES (c1_rec.MPAN_CORE, l_min_date, l_max_date, c1_rec.QUOTE_ID, l_nextval, p_user_comment, l_no_cont, 'M7038') ;
            END IF ;

            l_sum := nvl (c1_rec.VAL_1, 0) + nvl (c1_rec.VAL_2, 0) + nvl (c1_rec.VAL_3, 0) + nvl (c1_rec.VAL_4, 0) + nvl (c1_rec.VAL_5, 0) + nvl (c1_rec.VAL_6, 0) +
                     nvl (c1_rec.VAL_7, 0) + nvl (c1_rec.VAL_8, 0) + nvl (c1_rec.VAL_9, 0) + nvl (c1_rec.VAL_10, 0) + nvl (c1_rec.VAL_11, 0) + nvl (c1_rec.VAL_12, 0) +
                     nvl (c1_rec.VAL_13, 0) + nvl (c1_rec.VAL_14, 0) + nvl (c1_rec.VAL_15, 0) + nvl (c1_rec.VAL_16, 0) + nvl (c1_rec.VAL_17, 0) + nvl (c1_rec.VAL_18, 0) +
                     nvl (c1_rec.VAL_19, 0) + nvl (c1_rec.VAL_20, 0) + nvl (c1_rec.VAL_21, 0) + nvl (c1_rec.VAL_22, 0) + nvl (c1_rec.VAL_23, 0) + nvl (c1_rec.VAL_24, 0) +
                     nvl (c1_rec.VAL_25, 0) + nvl (c1_rec.VAL_26, 0) + nvl (c1_rec.VAL_27, 0) + nvl (c1_rec.VAL_28, 0) + nvl (c1_rec.VAL_29, 0) + nvl (c1_rec.VAL_30, 0) +
                     nvl (c1_rec.VAL_31, 0) + nvl (c1_rec.VAL_32, 0) + nvl (c1_rec.VAL_33, 0) + nvl (c1_rec.VAL_34, 0) + nvl (c1_rec.VAL_35, 0) + nvl (c1_rec.VAL_36, 0) +
                     nvl (c1_rec.VAL_37, 0) + nvl (c1_rec.VAL_38, 0) + nvl (c1_rec.VAL_39, 0) + nvl (c1_rec.VAL_40, 0) + nvl (c1_rec.VAL_41, 0) + nvl (c1_rec.VAL_42, 0) +
                     nvl (c1_rec.VAL_43, 0) + nvl (c1_rec.VAL_44, 0) + nvl (c1_rec.VAL_45, 0) + nvl (c1_rec.VAL_46, 0) + nvl (c1_rec.VAL_47, 0) + nvl (c1_rec.VAL_48, 0) +
                     nvl (c1_rec.VAL_49, 0) + nvl (c1_rec.VAL_50, 0) ;

            INSERT INTO HH_EDF_CONT_CONS_OLAY
            (MPAN_CORE, CONS_DATE,
             VAL_1, VAL_2, VAL_3, VAL_4, VAL_5, VAL_6, VAL_7, VAL_8, VAL_9, VAL_10, VAL_11, VAL_12, VAL_13,
             VAL_14, VAL_15, VAL_16, VAL_17, VAL_18, VAL_19, VAL_20, VAL_21, VAL_22, VAL_23, VAL_24, VAL_25,
             VAL_26, VAL_27, VAL_28, VAL_29, VAL_30, VAL_31, VAL_32, VAL_33, VAL_34, VAL_35, VAL_36, VAL_37,
             VAL_38, VAL_39, VAL_40, VAL_41, VAL_42, VAL_43, VAL_44, VAL_45, VAL_46, VAL_47, VAL_48, VAL_49,
             VAL_50, DAY_TOTAL, OVERLAY_VERSION, EQU_DATE, QUOTE_ID, RN)
            VALUES (c1_rec.MPAN_CORE, c1_rec.SETTLEMENT_DATE,
                    c1_rec.VAL_1, c1_rec.VAL_2, c1_rec.VAL_3, c1_rec.VAL_4, c1_rec.VAL_5, c1_rec.VAL_6, c1_rec.VAL_7,
                    c1_rec.VAL_8, c1_rec.VAL_9, c1_rec.VAL_10, c1_rec.VAL_11, c1_rec.VAL_12, c1_rec.VAL_13, c1_rec.VAL_14,
                    c1_rec.VAL_15, c1_rec.VAL_16, c1_rec.VAL_17, c1_rec.VAL_18, c1_rec.VAL_19, c1_rec.VAL_20, c1_rec.VAL_21,
                    c1_rec.VAL_22, c1_rec.VAL_23, c1_rec.VAL_24, c1_rec.VAL_25, c1_rec.VAL_26, c1_rec.VAL_27, c1_rec.VAL_28,
                    c1_rec.VAL_29, c1_rec.VAL_30, c1_rec.VAL_31, c1_rec.VAL_32, c1_rec.VAL_33, c1_rec.VAL_34, c1_rec.VAL_35,
                    c1_rec.VAL_36, c1_rec.VAL_37, c1_rec.VAL_38, c1_rec.VAL_39, c1_rec.VAL_40, c1_rec.VAL_41, c1_rec.VAL_42,
                    c1_rec.VAL_43, c1_rec.VAL_44, c1_rec.VAL_45, c1_rec.VAL_46, c1_rec.VAL_47, c1_rec.VAL_48, c1_rec.VAL_49,
                    c1_rec.VAL_50, l_sum, to_char (l_nextval), NULL, c1_rec.QUOTE_ID, NULL) ;

        END LOOP ;

    END CASE ;

    COMMIT ;

    -- Rebuild index because partitions have changed and the index is global!
    EXECUTE IMMEDIATE 'alter index i1_mpan rebuild' ;

    -- Now extrapolate!
    HH_EDF_CONT_CONS.sp_extrapolate_raw (-1, add_months (SYSDATE, -18), add_months (SYSDATE, 60) + 1) ;

    -- Exception handler
EXCEPTION
    WHEN OTHERS THEN
         l_err_msg := SQLCODE || ' ' || SQLERRM ;
         ROLLBACK ;
         RAISE ;


END SP_LOAD_BULK_OVERLAY ;
/
