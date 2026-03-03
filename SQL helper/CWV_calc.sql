
DECLARE
po_retval VARCHAR2 (4000) ;
BEGIN

sp_merge_calc_variable_data (410, po_retval) ;
dbms_output.put_line (po_retval) ;

END ;

SELECT *  FROM   wk_weather_variable_data_calc
                               WHERE  calculation_id = 410 ;

-- Area requirement
INSERT INTO WET_DATA.VW_AREA_REQ
            (AREA_ID, AREA_ALIAS)
       SELECT AREA_ID, ALIAS_NAME
       FROM   WET_CNF.AREA_REQUIREMENT_CALC WHERE CALCULATION_ID = 410 ;
       
-- Report requirement
INSERT INTO WET_DATA.VW_REPORT_REQ
            (ACTIVE_FLAG, BASELINE_DATE, TIME_RESOLUTION, TIME_REGIME,CALENDAR_ID)
       SELECT 1, NULL, TIME_RESOLUTION, TIME_REGIME_ID , 0
       FROM   WET_CNF.REPORT_REQUIREMENT_CALC WHERE CALCULATION_ID = 410 ;

-- Get variable requirement       
SELECT v.WEATHER_VARIABLE_ID, SCENARIO_ID, A_F_IND,
       TO_CHAR (SYSDATE + OFFSET_START, 'DD/MM/YYYY') AS "FROM_DATE",
       TO_CHAR (SYSDATE + OFFSET_END, 'DD/MM/YYYY') AS "TO_DATE",
       OUTPUT_ALIAS , UNIT_OF_MEASURE_CODE,
       d.default_weather_variable_id,
       d.default_scenario_id,
       d.extrapolate_hours_until_sn
FROM   WET_CNF.VARIABLE_REQUIREMENT v,
       wet_cnf.default_normal_scenario d
WHERE  REPORT_ID = 106
       AND v.weather_variable_id = d.weather_variable_id(+)
       AND    SYSDATE BETWEEN d.effective_from_date(+)
                      AND nvl(d.effective_to_date(+),SYSDATE)
ORDER BY WEATHER_VARIABLE_ID ASC ;

SELECT * FROM WET_DATA.VW_VARIABLE_REQ ;

-- Variable requirement
INSERT INTO WET_DATA.VW_VARIABLE_REQ
           (WEATHER_VARIABLE_ID, WEATHER_VARIABLE_ALIAS, SCENARIO_ID, MEASUREMENT_TYPE, 
            FROM_DATETIME, TO_DATETIME, UNIT_OF_MEASURE_CODE)
SELECT v.WEATHER_VARIABLE_ID, OUTPUT_ALIAS, SCENARIO_ID, A_F_IND,
       TO_DATE (TO_CHAR (SYSDATE -747, 'DD/MM/YYYY'), 'DD/MM/YYYY') AS "FROM_DATE",
       TO_DATE (TO_CHAR (SYSDATE - 736, 'DD/MM/YYYY'), 'DD/MM/YYYY') AS "TO_DATE",
       UNIT_OF_MEASURE_CODE
FROM   WET_CNF.VARIABLE_REQUIREMENT_CALC v,
       wet_cnf.default_normal_scenario d
WHERE  CALCULATION_ID = 410
       AND v.weather_variable_id = d.weather_variable_id(+)
       AND    SYSDATE BETWEEN d.effective_from_date(+)
                      AND nvl(d.effective_to_date(+),SYSDATE)

SELECT * FROM   WET_CNF.VARIABLE_REQUIREMENT_CALC v WHERE calculation_id = 410 ;

-- Get data from VW_REPORT
WITH base_data AS (SELECT 99999 AS REPORT_RUN_ID, PROVIDER_ID, WEATHER_VARIABLE_ID, WEATHER_VARIABLE_ALIAS, 
       WEATHER_VARIABLE_TYPE_ID, MEASUREMENTTYPE_REQUESTED, MEASUREMENTTYPE_RETURNED,
       SCENARIO_ID, WEATHER_TIME, DATA_DATETIME, DATA_STATUS,
       VARIABLE_VALUE, OVERRIDE_FLAG, FILE_ID, AREA_ID, AREA_ALIAS , PERIOD_ID
FROM   WET_DATA.VW_REPORT
)
   SELECT weather_Variable_id, weather_time, area_id, scenario_id, file_id, COUNT (*)
   FROM base_data
   GROUP BY weather_Variable_id, weather_time, area_id, scenario_id, file_id
   HAVING COUNT (*) > 1 
ORDER BY weather_Variable_id, weather_time, area_id ;

DROP TABLE csaba_cwv ;

CREATE TABLE csaba_cwv AS 
SELECT 99999 AS REPORT_RUN_ID, PROVIDER_ID, WEATHER_VARIABLE_ID, WEATHER_VARIABLE_ALIAS, 
       WEATHER_VARIABLE_TYPE_ID, MEASUREMENTTYPE_REQUESTED, MEASUREMENTTYPE_RETURNED,
       SCENARIO_ID, WEATHER_TIME, DATA_DATETIME, DATA_STATUS,
       VARIABLE_VALUE, OVERRIDE_FLAG, FILE_ID, AREA_ID, AREA_ALIAS , PERIOD_ID, LOGICAL_DATE
FROM   WET_DATA.VW_REPORT ;


-- Current report run view
INSERT INTO VW_CURR_REPORT_RUN (REPORT_RUN_ID) VALUES (1044) ;

-- Select from final view
SELECT * 
FROM   VW_REPORT_7_ST_HH
WHERE  REPORT_RUN_ID = 1044 ;

WITH uoms AS (
    SELECT MAX(DECODE(weather_variable_alias,'WIND_SPEED',u.unit_of_measure_code,NULL))  AS wind_FROM_uom,
           MAX(DECODE(weather_variable_alias,'WIND_SPEED',r.unit_of_measure_code,NULL))  AS wind_to_uom  ,
           MAX(DECODE(weather_variable_alias,'TEMPERATURE',u.unit_of_measure_code,NULL)) AS temp_FROM_uom,
           MAX(DECODE(weather_variable_alias,'TEMPERATURE',r.unit_of_measure_code,NULL)) AS temp_to_uom
    FROM   vw_variable_req r,
           wet_cnf.weather_variable wv ,
           wet_cnf.weather_variable_type_uom u
    WHERE  r.Weather_Variable_Id           = wv.weather_variable_id
           AND wv.weather_variable_type_id = u.weather_variable_type_id
           AND u.default_uom               = 1
), base_data AS (
    SELECT r.area_id                        ,
           s.output_scenario_id AS scenario_id  ,
           r.weather_variable_alias             ,
           r.measurementtype_returned AS a_f_ind,
           weather_time                         ,
           logical_date                        AS weather_date         ,
           TO_CHAR (r.weather_time, 'HH24:MI') AS period               ,
           r.variable_value                                            ,
           calculation_id
    FROM   wet_data.csaba_cwv r,
           wet_data.vw_output_scen_req s
), periods AS (
    SELECT w.time    AS period,
           'TEMPERATURE' AS wv    ,
           w.weight
    FROM wet_cnf.cwv_at_weight w
    UNION ALL
    SELECT w.time   AS period,
           'WIND_SPEED' AS wv    ,
           1            AS weight
    FROM wet_cnf.cwv_w_time w
    UNION ALL
    SELECT 'SNET' AS period, 'SNET' AS wv,1 AS weight FROM dual
), pre_filtered AS (
    SELECT b.area_id           ,
           b.scenario_id           ,
           b.weather_date          ,
           b.period                ,
           p.wv                    ,
           b.weather_variable_alias,
           CASE WHEN p.wv = 'S' THEN 'A' ELSE b.a_f_ind END AS a_f_ind,
           b.variable_value,
           p.weight        ,
           calculation_id  ,
           weather_time
    FROM   base_data b,
           periods p
    WHERE p.period = DECODE(b.weather_variable_alias,'SNET','SNET',b.period)
          AND p.wv = b.weather_variable_alias
), piv_wind AS (
    SELECT area_id ,
           scenario_id ,
           weather_date,
           MAX (f.a_f_ind) KEEP (dense_rank FIRST ORDER BY d.a_f_rank DESC) AS a_f_ind,
           SUM(DECODE(wv,'SNET',variable_value        * weight,NULL)) AS snet       ,
           SUM(DECODE(wv,'TEMPERATURE',variable_value * weight,NULL)) AS actual_temp,
           AVG(DECODE(wv,'WIND_SPEED',variable_value  * weight,NULL)) AS wind_speed ,
           calculation_id
    FROM   pre_filtered f,
           wet_cnf.actual_forecast_dim d
    WHERE f.a_f_ind = d.a_f_ind
    GROUP BY area_id,
             scenario_id  ,
             weather_date ,
             calculation_id
), sum_avg AS (
    SELECT area_id        ,
         scenario_id        ,
         a_f_ind            ,
         calculation_id     ,
         trunc (weather_date) AS weather_date,
             SUM (ACTUAL_TEMP) AS actual_temp, MAX (SNET) AS snet, AVG (WIND_SPEED) AS wind_speed
      FROM piv_wind
      GROUP BY trunc (weather_date),
               area_id             ,
               scenario_id         ,
               a_f_ind             ,
               calculation_id
   ),
   eff_temp AS
   (
      SELECT area_id        ,
         scenario_id        ,
         a_f_ind            ,
         weather_variable_id,
         weather_date       ,
         actual_temp        ,
         effective_temp     ,
         wind_speed         ,
         snet
      FROM sum_avg p,
         wet_cnf.calculation_output_variable v
      WHERE p.calculation_id            = v.calculation_id(+)
      AND v.calculation_output_alias(+) = 'EFFECTIVE_TEMP'
      MODEL PARTITION BY (area_id, scenario_id, a_f_ind, weather_variable_id)
      DIMENSION BY (weather_date) MEASURES (actual_temp, actual_temp effective_temp,wind_speed, snet)
      RULES AUTOMATIC ORDER ( effective_temp [ANY] = DECODE( effective_temp [cv (weather_date) - 1], NULL,NVL(fn_get_sn_value(cv(weather_variable_id), cv(area_id), cv(scenario_id), cv(weather_date) -1),actual_temp [cv (weather_date)]), (0.5 * actual_temp [cv (weather_date)]) + (0.5 * effective_temp [cv (weather_date) - 1])) )
      ORDER BY weather_date ASC
   )
   ,
   conversions AS
   (
      SELECT area_id                                                                                                            ,
         scenario_id                                                                                                            ,
         weather_date                                                                                                           ,
         a_f_ind                                                                                                                ,
         pkg_conversion.fn_convert(p_value => actual_temp,p_from => u.temp_from_uom, p_to => u.temp_to_uom)    AS actual_temp   ,
         pkg_conversion.fn_convert(p_value => effective_temp,p_from => u.temp_from_uom, p_to => u.temp_to_uom) AS effective_temp,
         pkg_conversion.fn_convert(p_value => wind_speed,p_from => u.wind_from_uom, p_to => u.wind_to_uom)     AS wind_speed_kts,
         wind_speed,
         snet
      FROM eff_temp e,
         uoms u
   )
   ,
   constants AS
   (
      SELECT cons.*
      FROM wet_cnf.provider_cwv_constant_version pc,
         vw_variable_req vr                       ,
         wet_cnf.weather_variable v                ,
         wet_cnf.cwv_constant cons
      WHERE pc.provider_id          = v.provider_id
      AND vr.weather_variable_alias = 'TEMPERATURE'
      AND SYSDATE BETWEEN pc.effective_from_date AND NVL(pc.effective_to_date, SYSDATE)
      AND vr.weather_variable_id     = v.weather_variable_id
      AND pc.cwv_constant_version_id = cons.cwv_constant_version_id
   )
   ,
   cw AS
   (
      SELECT eft.area_id                                                                                                                                           ,
         eft.scenario_id                                                                                                                                           ,
         eft.weather_date                                                                                                                                          ,
         a_f_ind                                                                                                                                                   ,
         actual_temp                                                                                                                                               ,
         effective_temp                                                                                                                                            ,
         wind_speed                                                                                                                                                ,
         cons.l1 * effective_temp + NVL ((1 - cons.l1) * eft.snet, 0) - l2 * greatest (0, eft.wind_speed_kts - cons.w0) * greatest (0, cons.t0 - eft.actual_temp) AS cw,
         cons.v1                                                                                                                                                   ,
         cons.v2                                                                                                                                                   ,
         cons.q                                                                                                                                                    ,
         cons.v0                                                                                                                                                   ,
         cons.l3
      FROM conversions eft,
         constants cons   ,
         wet_cnf.area a
      WHERE eft.area_id = a.area_id
      AND a.area_name   = cons.ldz
   )
   ,
   cwv AS
   (
      SELECT cw.area_id ,
         cw.scenario_id ,
         cw.weather_date,
         a_f_ind        ,
         actual_temp    ,
         effective_temp ,
         wind_speed     ,
         CASE
            WHEN v2 <= cw
            THEN v1 + q * (v2 - v1)
            WHEN v1 < cw
            AND cw  < v2
            THEN v1 + q * (cw - v1)
            WHEN v0 <= cw
            AND cw  <= v1
            THEN cw
            WHEN v0 > cw
            THEN cw + l3 * (cw - v0)
            ELSE NULL
         END AS cwv
      FROM cw
   )
   ,
   unpivot_set AS
   (
      SELECT area_id           ,
         scenario_id           ,
         weather_date          ,
         a_f_ind               ,
         weather_variable_alias,
         variable_value
      FROM cwv UNPIVOT INCLUDE NULLS ( VARIABLE_value FOR weather_variable_alias IN (cwv, actual_temp, effective_temp,wind_speed) )
   )
   ,
   final_one AS
   (
      SELECT weather_variable_alias                           ,
         weather_date AS weather_time                         ,
         area_id                                              ,
         a_f_ind                                              ,
         scenario_id                                          ,
         SYSDATE AS data_datetime                             ,
         variable_value                                       ,
         DECODE(variable_value,NULL,'I','C') AS data_status   ,
         to_number (NULL)                    AS override_value,
         -1                                  AS file_id
      FROM unpivot_set
   )
SELECT weather_variable_alias,
   weather_time              ,
   area_id                   ,
   a_f_ind                   ,
   scenario_id               ,
   data_datetime             ,
   variable_value            ,
   data_status               ,
   override_value            ,
   file_id
FROM final_one;

SELECT * FROM VW_CWV ;

SELECT COUNT (*) FROM csaba_cwv ;

SELECT * FROM wet_data.weather_variable_data WHERE variable_value = -0.47377
