-- Strange MERGE behaviour

-- Sequence is fowarded by one despite no INSERT. Looks like the VALUES () are prepared upfront
-- then the WHERE-clause is evaluated which says only DML_TPYE = 'I' which results in no rows being inserted
-- yet the sequence has been incremented!

-- ****************************************
-- Standard, documented behaviour. Sequences are incremented in MERGE despite not being used
-- ****************************************

      -- Get current sequence value
      select WESP_RPT.WR_ACCOUNT_HOLDER_ID_SEQ.CURRVAL from dual ;

      SELECT * 
      FROM   WESP_RPT.ACCOUNT_HOLDER
--      where cups_id = 199210449
--            and cntr_id = 397099
      where account_holder_id = 3515041
      WHERE  EFFECTIVE_FROM_DATE = TO_DATE ('15/01/2013', 'DD/MM/YYYY') ;    

MERGE INTO WESP_RPT.VW_ACCOUNT_HOLDER_UPI AH
  USING (SELECT NULL as ACCOUNT_HOLDER_ID
         ,      210449 as CUPS_ID
         ,      223397099 as CNTR_ID
         ,      NULL as EMAIL
         ,      NULL as LOPD
         ,      NULL as LOPD_GROUP
         ,      NULL as TELEPHONE_1
         ,      NULL as TELEPHONE_2
         ,      NULL as TELEPHONE_3
         ,      NULL as TELEPHONE_4
         ,      NULL as TELEPHONE_5
         ,      NULL as POST_CODE
         ,      NULL as ADDRESS_LINE_1
         ,      NULL as ADDRESS_LINE_2
         ,      NULL as ADDRESS_LINE_3
         ,      NULL as ADDRESS_LINE_4
         ,      NULL as ADDRESS_LINE_5
         ,      NULL as ADDRESS_LINE_6
         ,      NULL as ADDRESS_LINE_7
         ,      NULL as ADDRESS_LINE_8
         ,      NULL as ADDRESS_LINE_9
         ,      NULL as ADDRESS_LINE_10
         ,      NULL as FIRSTNAME
         ,      NULL as LASTNAME
         ,      NULL as DNI_CIF
         ,      NULL as KAM
         ,      NULL as EMPLOYEE
         ,      NULL as CUSTOMER_CURRENT_ST
         ,      NULL as CUSTOMER_EARLIEST_ST
         ,      NULL as CNAE
         ,      NULL as EON_CUSTOMER_ID
         ,      NULL as KAM_CUSTOMER_INDICATOR
         ,      v.DML_TYPE
         FROM   DUAL, WESP_HDS.VW_DML_TYPE v) A
  ON (    AH.CUPS_ID  = A.CUPS_ID
     /* AND AH.DNI_CIF  = A.DNI_CIF   */
      AND AH.CNTR_ID  = A.CNTR_ID
      AND AH.DML_TYPE = A.DML_TYPE )
  WHEN MATCHED THEN
     UPDATE SET AH.EFFECTIVE_TO_DATE = (SELECT TO_DATE(PARAMETER_VALUE,'YYMMDD') FROM WESP_MGT.MGMT_T_PARAMETERS WHERE PARAMETER_NAME = 'BATCH_DATE') -1
  WHEN NOT MATCHED THEN
     INSERT (ACCOUNT_HOLDER_ID
            ,EFFECTIVE_FROM_DATE
            ,EFFECTIVE_TO_DATE
       ,CUPS_ID
            ,CNTR_ID
            ,EMAIL
            ,LOPD
            ,LOPD_GROUP
            ,TELEPHONE_1
            ,TELEPHONE_2
            ,TELEPHONE_3
            ,TELEPHONE_4
            ,TELEPHONE_5
            ,POST_CODE
            ,ADDRESS_LINE_1
            ,ADDRESS_LINE_2
            ,ADDRESS_LINE_3
            ,ADDRESS_LINE_4
            ,ADDRESS_LINE_5
            ,ADDRESS_LINE_6
            ,ADDRESS_LINE_7
            ,ADDRESS_LINE_8
            ,ADDRESS_LINE_9
            ,ADDRESS_LINE_10
            ,FIRSTNAME
            ,LASTNAME
            ,DNI_CIF
            ,KAM
            ,EMPLOYEE
            ,CUSTOMER_CURRENT_ST
            ,CUSTOMER_EARLIEST_ST
            ,CNAE
            ,EON_CUSTOMER_ID
            ,KAM_CUSTOMER_INDICATOR
            ,ACCOUNT_HOLDER_EFD
       )
     VALUES (NVL(A.ACCOUNT_HOLDER_ID,WESP_RPT.WR_ACCOUNT_HOLDER_ID_SEQ.NEXTVAL)
            ,(SELECT TO_DATE(PARAMETER_VALUE,'YYMMDD') FROM WESP_MGT.MGMT_T_PARAMETERS WHERE PARAMETER_NAME = 'BATCH_DATE') /* EFFECTIVE_FROM_DATE */
            ,NULL /* EFFECTIVE_TO_DATE */
            ,A.CUPS_ID
            ,A.CNTR_ID
            ,A.EMAIL
            ,A.LOPD
            ,A.LOPD_GROUP
            ,A.TELEPHONE_1
            ,A.TELEPHONE_2
            ,A.TELEPHONE_3
            ,A.TELEPHONE_4
            ,A.TELEPHONE_5
            ,A.POST_CODE
            ,A.ADDRESS_LINE_1
            ,A.ADDRESS_LINE_2
            ,A.ADDRESS_LINE_3
            ,A.ADDRESS_LINE_4
            ,A.ADDRESS_LINE_5
            ,A.ADDRESS_LINE_6
            ,A.ADDRESS_LINE_7
            ,A.ADDRESS_LINE_8
            ,A.ADDRESS_LINE_9
            ,A.ADDRESS_LINE_10
            ,A.FIRSTNAME
            ,A.LASTNAME
            ,A.DNI_CIF
            ,A.KAM
            ,A.EMPLOYEE
            ,A.CUSTOMER_CURRENT_ST
            ,A.CUSTOMER_EARLIEST_ST
            ,A.CNAE
            ,A.EON_CUSTOMER_ID
            ,A.KAM_CUSTOMER_INDICATOR
            ,NVL (A.ACCOUNT_HOLDER_ID, WESP_RPT.WR_ACCOUNT_HOLDER_ID_SEQ.NEXTVAL) || '|' || (SELECT TO_CHAR (TO_DATE (PARAMETER_VALUE,'YYMMDD'), 'YYYYMMDD') FROM WESP_MGT.MGMT_T_PARAMETERS WHERE PARAMETER_NAME = 'BATCH_DATE')
       )
      WHERE  A.DML_TYPE = 'I' ;
