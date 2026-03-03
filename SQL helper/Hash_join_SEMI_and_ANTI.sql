SELECT /*+ INDEX (HIST INV_DATA_STAT_HIST_EFD_BM_IDX) */ 
       HIST.INVOICE_DATA_ID
,      HIST.EFFECTIVE_FROM_DATE
,      HIST.EFFECTIVE_TO_DATE
,      HIST.CUPS_ID
,      HIST.INVOICE_ID
,      HIST.INVOICE_STATUS_DT
,      HIST.INVOICE_STATUS
,      HIST.DEBT_STATUS
,      'U' AS DML_TYPE
FROM   WESP_RPT.INVOICE_DATA_STATUS_HIST HIST
WHERE  NVL2 (HIST.EFFECTIVE_TO_DATE, 0, 1) = 1
       AND HIST.INVOICE_STATUS NOT IN ('PAID', 'CANCELLED')
       AND EXISTS (SELECT NULL 
                          FROM   WESP_HDS.BILLING BILL
                          WHERE  BILL.INVOICE_ID = HIST.INVOICE_ID
                                 AND BILL.EFFECTIVE_FROM_DATE = (SELECT TO_DATE (PARAMETER_VALUE,'YYMMDD')
                                                             FROM   WESP_MGT.MGMT_T_PARAMETERS
                                                             WHERE  PARAMETER_NAME = 'BATCH_DATE')) ;
-- Hash join SEMI
-- Once a corresponding row is found in the subquery the search can stop unlike in hash joins
-- Only a single row is returned per each row of the driving table although there could be more matching rows
-- in the other table

SELECT /*+ INDEX (HIST INV_DATA_STAT_HIST_EFD_BM_IDX) */ 
       HIST.INVOICE_DATA_ID
,      HIST.EFFECTIVE_FROM_DATE
,      HIST.EFFECTIVE_TO_DATE
,      HIST.CUPS_ID
,      HIST.INVOICE_ID
,      HIST.INVOICE_STATUS_DT
,      HIST.INVOICE_STATUS
,      HIST.DEBT_STATUS
,      'U' AS DML_TYPE
FROM   WESP_RPT.INVOICE_DATA_STATUS_HIST HIST
WHERE  NVL2 (HIST.EFFECTIVE_TO_DATE, 0, 1) = 1
       AND HIST.INVOICE_STATUS NOT IN ('PAID', 'CANCELLED')
       AND NOT EXISTS (SELECT NULL 
                          FROM   WESP_HDS.BILLING BILL
                          WHERE  BILL.INVOICE_ID = HIST.INVOICE_ID
                                 AND BILL.EFFECTIVE_FROM_DATE = (SELECT TO_DATE (PARAMETER_VALUE,'YYMMDD')
                                                             FROM   WESP_MGT.MGMT_T_PARAMETERS
                                                             WHERE  PARAMETER_NAME = 'BATCH_DATE')) ;
-- Hash join ANTI
-- The opposite of Hash join SEMI. If a matching row is found, the search can stop and the raw is dropped
