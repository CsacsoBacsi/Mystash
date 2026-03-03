 WITH hds AS (
  -- Primary Key
  -- ===========
  -- DW_FROM_DATE,PRODUCT_ACCOUNT_REFERENCE,CUSTOMER_LOCATION_DETAIL_ID, CONTEXT_TYPE, BASE_ID, KEY_TYPE
  -- continued... FINANCIAL_ACCOUNT_REFERENCE, ICE_CUSTOMER_ID, START_DATE
  -- ---------------------------------------------------------------------------
  --
  -- Most of the sub-queries in this view are there to identify the latest state of play
  -- recorded in the customer location context HDS, for any given point in time.
  -- The approach has been to
  --   1. create an "event_date" from which any change has occurred (add_and_remove_events)
  --   2. discard all except for one record for any given event_date (order_replacements)
  --   3. discard event records for which there is no change in data (identify_prev_payload
  --                                                        and identify_change_event_dates)
  --   4. manufacture dw_from_date and dw_to_dates from the event_dates (cust_loc_cntxt_lnk)
  --
    SELECT from_date, to_date, customer_location_detail_id, start_date, end_date, context_type_id, cust_loc_context_instance_id
    FROM   ae_hds.hds_t_vul1_cust_loc_cntxt_lnk
    WHERE  start_date < NVL(end_date, date '9999-12-31') /* eliminate bad data load */
    UNION ALL
    SELECT from_date, to_date, customer_location_detail_id, start_date, end_date, context_type_id, cust_loc_context_instance_id
    FROM   ae_hds.hds_t_vul2_cust_loc_cntxt_lnk
    WHERE  start_date < NVL(end_date, date '9999-12-31') /* eliminate bad data load */
  ), add_and_remove_events AS (
    SELECT 'A' AS event, from_date AS event_date, customer_location_detail_id,
           start_date, end_date, context_type_id, cust_loc_context_instance_id
    FROM   hds
    UNION ALL
    SELECT 'R' AS event, to_date + 1 AS event_date, customer_location_detail_id,
           start_date, end_date, context_type_id, cust_loc_context_instance_id
    FROM   hds
    WHERE  to_date IS NOT NULL
  ), order_replacements AS (
    SELECT ROW_NUMBER() OVER (PARTITION BY event_date, customer_location_detail_id, context_type_id
                                           -- Keep "A"dded events in preference to "R"emoved eventS
                                  ORDER BY event, cust_loc_context_instance_id DESC) AS rn,
           event_date, customer_location_detail_id, context_type_id, start_date, end_date
    FROM   add_and_remove_events
  ), identify_prev_payload AS (
    SELECT customer_location_detail_id, context_type_id, start_date, end_date, event_date,
           LAG(start_date) OVER (PARTITION BY customer_location_detail_id, context_type_id ORDER BY event_date) prev_start_date,
           LAG(  end_date) OVER (PARTITION BY customer_location_detail_id, context_type_id ORDER BY event_date) prev_end_date
    FROM   order_replacements
    WHERE  rn = 1
  ), identify_change_event_dates AS (
    SELECT customer_location_detail_id, context_type_id, start_date, end_date, event_date,
           CASE WHEN start_date = prev_start_date
                AND  NVL(end_date, date '1970-01-01') = NVL(prev_end_date, date '1970-01-01')
                THEN 'N'
                ELSE 'Y'
           END change_indicator
    FROM   identify_prev_payload
  ), cust_loc_cntxt_lnk AS (
    SELECT customer_location_detail_id, context_type_id, start_date, end_date,
           event_date AS dw_from_date,
           LEAD(event_date - 1, 1, date '9999-12-31')
             OVER (PARTITION BY customer_location_detail_id, context_type_id
                       ORDER BY event_date) AS dw_to_date
    FROM   identify_change_event_dates
    WHERE  change_indicator = 'Y'
  )