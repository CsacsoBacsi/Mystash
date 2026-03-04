source_table = "csaba_src"
target_table = "csaba_trg"
all_columns = ["key1", "key2", "key3", "val1"]
select_cols = ", ".join ([f"{k}" for k in all_columns]) + ","
ua_select_cols = ", ".join ([f"ua.{k}" for k in all_columns]) + ","
merge_on_left = " ".join([f"trg.{k} || \'||\' ||" for k in all_columns])
merge_on_right = " ".join([f"src.{k} || \'||\' ||" for k in all_columns])
insert_cols = ", ".join ([f"src.{k}" for k in all_columns])

sql = f"""
MERGE INTO {target_table} AS t USING
    (WITH ua AS ( 
        SELECT {select_cols}
               1 AS ind1, -- Exists in source
               NULL AS ind2
        FROM   {source_table}
        WHERE  1=1  
        UNION ALL 
        SELECT {select_cols} 
               NULL AS ind1,
               1 AS ind2 -- Exists in target
        FROM   {target_table} 
        WHERE  end_date IS NULL  
    )
    SELECT {ua_select_cols}
           CASE WHEN COUNT (ua.ind2) = 0 AND COUNT (ua.ind1) = 1 THEN 'I' -- Row in source not in target, e.g. new row (needs inserting)
                WHEN COUNT (ua.ind1) = 0 AND COUNT (ua.ind2) = 1 THEN 'U' -- Row in target not in source, e.g. deleted row (needs end dating)
                ELSE                                                  'Q' -- 1 on both sides means no change, e.g. same row If more than 1, it means dupes present
            END AS transaction_type, 
            COUNT (ua.ind1) count_ind1, -- For recon and testing purposes only
            COUNT (ua.ind2) count_ind2, -- For recon and testing purposes only
            current_date as start_date,
            current_date -1 as end_date 
    FROM  ua 
    GROUP BY {ua_select_cols} -- Check all columns if they are different. Basically distinct list
    HAVING COUNT (ua.ind1) != COUNT (ua.ind2)
    ) AS src -- Only when there is a difference. Otherwise no change, so ignore
ON ({merge_on_left} 'U' = 
    {merge_on_right} src.transaction_type) -- Merge key: primary key columns
WHEN MATCHED AND t.end_date IS NULL THEN -- There can be a multi-row history for a key, so leave those rows and operate on current/live row only
    UPDATE SET end_date = src.end_date -- Update only the end date (close row off). New data will be inserted.
WHEN NOT MATCHED AND transaction_type = 'I' THEN -- Row of type 'I' is only present in target, so insert
    INSERT ({select_cols[:-1]}, start_date, end_date) 
    VALUES ({insert_cols}, src.start_date, NULL) 
"""

r = 5

