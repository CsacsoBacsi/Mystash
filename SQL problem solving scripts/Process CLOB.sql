CREATE OR REPLACE PROCEDURE FINANCE.sp_load_equivalent_dates (p_cfr_file_id NUMBER) IS 
-- Purpose:        To populate FTP's equivalent date mapping table. 
--                 The generic file loader is supposed to call this procedure
-- Parameters      CLOBId
-- Created by:     Csaba Riedlinger
-- Date:           16/12/2008
-- Change history: 
-- 

    v_clob_length       PLS_INTEGER ;       -- CLOB length
    v_recno             PLS_INTEGER ;       -- Row number
    v_row               VARCHAR2 (2000) ;   -- Row (chars between line feeds)
    v_col1              VARCHAR2 (100) ;    -- The 4 columns of the CSV file  
    v_col2              VARCHAR2 (100) ;
    v_col3              VARCHAR2 (100) ;        
    v_col4              VARCHAR2 (100) ;
    v_pos1              PLS_INTEGER ;       -- Marks the position of commas on a particular row
    v_pos2              PLS_INTEGER ;
    v_pos3              PLS_INTEGER ;
    v_offset            PLS_INTEGER := 1 ;  -- Marks the end of the last read portion of the CLOB
    v_length            PLS_INTEGER ;       -- The length of bytes read (as a row)

    CURSOR  c_main                          -- Returns the CLOB and user name (and more...)
    IS
    SELECT  a.cfr_file_id
            ,a.cfr_filetype
            ,a.cfr_filename
            ,a.cfr_host
            ,a.cfr_env
            ,a.cfr_username
            ,a.cfr_text                     -- CLOB
            ,a.cfr_date_received
            ,a.cfr_comments
    FROM    finance.cfl_text_files_received a
    WHERE   a.cfr_file_id = p_cfr_file_id ;
    
    r_main c_main%ROWTYPE ;
    
BEGIN

    -- Get the CLOB + info
    OPEN    c_main;
    FETCH   c_main INTO r_main ;
    CLOSE   c_main ;
    
    v_clob_length  := dbms_lob.getlength (r_main.cfr_text) ;
    
    -- Initialize temporary table
    IF v_clob_length > 0 THEN
        EXECUTE IMMEDIATE 'TRUNCATE TABLE FIN_T_EQU_DATE_TMP' ;
    END IF ;
    
    -- Header row
    v_row := fn_clob_read_line (r_main.cfr_text, v_offset) ;
    v_length := length (v_row) ;
    
    IF v_row = 'EOF' THEN -- This file (CLOB) must be empty
        dbms_output.put_line ('File seems to be empty. Exiting.') ;
        RETURN ;        
    END IF ;

    -- First row with real data
    v_offset := v_offset + v_length + 1 ; 
    v_row := fn_clob_read_line (r_main.cfr_text, v_offset) ;
    v_length := length (v_row) ;                    
    v_recno := 2 ; -- Count records
    
    -- Main loop to process CLOB row by row (row terminated by chr (10) - LineFeeds
    WHILE v_row <> 'EOF' LOOP

        -- Process row. Fields are separated by commas
        v_pos1 := instr (v_row, ',', 1, 1) ;
        v_pos2 := instr (v_row, ',', 1, 2) ;
        v_pos3 := instr (v_row, ',', 1, 3) ;                
        v_col1 := substr (v_row, 1, v_pos1 - 1) ;
        v_col2 := substr (v_row, v_pos1 + 1, v_pos2 - v_pos1 - 1) ;         
        v_col3 := substr (v_row, v_pos2 + 1, v_pos3 - v_pos2 - 1) ;    

        -- Insert row into temp table. Add username
        INSERT /*+ APPEND */ INTO FIN_T_EQU_DATE_TMP -- Insert into temp table first
               (THE_CURRENT_DATE, EQUIVALENT_DATE, LAST_UPDATE, LAST_UPDATED_BY)
               VALUES (v_col1, v_col2, v_col3, r_main.cfr_username) ;

        v_recno := v_recno + 1 ;
        -- IF v_recno = 50000 THEN
        --    EXIT ;
        -- END IF ;

        -- Get next row (if any still available)
        v_offset := v_offset + v_length + 1 ;
        v_row := fn_clob_read_line (r_main.cfr_text, v_offset) ;
        v_length := length (v_row) ;               
    
    END LOOP ; 
    
    COMMIT ;
    
    v_recno := v_recno - 1 ;
    dbms_output.put_line ('Read ' || v_recno || ' equivalent date mappings.') ;
    
    IF v_recno > 100000 THEN -- If at least a 100K rows were read
        EXECUTE IMMEDIATE 'TRUNCATE TABLE FIN_T_EQU_DATE' ;
       
        INSERT /*+ APPEND */ INTO FIN_T_EQU_DATE -- Copy data from temp table to target table
               (THE_CURRENT_DATE, EQUIVALENT_DATE, LAST_UPDATE, LAST_UPDATED_BY)
               SELECT THE_CURRENT_DATE, EQUIVALENT_DATE, LAST_UPDATE, LAST_UPDATED_BY
               FROM FIN_T_EQU_DATE_TMP ;
           
        COMMIT ;
    END IF ;
    
END sp_load_equivalent_dates ;
/

CREATE OR REPLACE FUNCTION FINANCE.fn_clob_read_line (p_clob CLOB, p_offset PLS_INTEGER) RETURN VARCHAR2 IS

v_to   PLS_INTEGER ;
v_amount PLS_INTEGER ;

BEGIN

    IF p_offset < 1 THEN
        RETURN 'EOF' ;
    END IF ;

    v_to := dbms_lob.instr (p_clob, chr (10), p_offset, 1) ;
    IF v_to = 0 THEN
        RETURN 'EOF' ;
    END IF ;
    v_amount := v_to - p_offset ; 
    
    RETURN dbms_lob.substr (p_clob, v_amount, p_offset) ;
    
END fn_clob_read_line ;
/