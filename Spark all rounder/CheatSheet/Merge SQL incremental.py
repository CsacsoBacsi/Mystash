'''
Incremental MERGE example in Delta Lake with Spark SQL. This code demonstrates how to perform an incremental merge from a source Delta table to a target Delta table, 
handling inserts and updates based on the presence of records in the source and target tables.

Source data can include multiple updates for the same key, new rows, and duplicates. The merge logic identifies whether a row should be end dated (closed).
Incremental means that we only want to update the target table with the latest changes from the source, without affecting unchanged records.

Example cases:
Key columns: key1, key2, key3
Non-key column: val1
Last 3 timestamp columns are: updated_at, start_date, end_date
1. val1 has been updated to 2. End date the current record and insert a new record with the updated value and new start date.
   Target: ('2', '1', '1', 1, 2026-01-01 12:12:12, 2026-01-01 12:12:12, None)
   Source: ('2', '1', '1', 2, 2026-01-02 12:12:12)
   Result: ('2', '1', '1', 1, 2026-01-01 12:12:12, 2026-01-01 12:12:12, 2026-01-02 12:12:11),
           ('2', '1', '1', 2, 2026-01-02 12:12:12, 2026-01-02 12:12:12, None)

2. val1 has been updated multiple times. First to 3 then to 4 then back to 3. End date the current record and insert the new records with the updated values and new start dates
    Target: ('1', '1', '1', 1, 2026-01-01 12:12:12, 2026-01-01 12:12:12, 2026-01-02 22:12:11),
            ('1', '1', '1', 2, 2026-01-02 22:12:12, 2026-01-02 22:12:12, None),
    Source: ('1', '1', '1', 3, 2026-01-03 23:12:12),
            ('1', '1', '1', 4, 2026-01-04 23:12:12),
            ('1', '1', '1', 3, 2026-01-05 23:12:12)
    Result: ('1', '1', '1', 1, 2026-01-01 12:12:12, 2026-01-01 12:12:12, 2026-01-02 22:12:11),
            ('1', '1', '1', 2, 2026-01-02 22:12:12, 2026-01-02 22:12:12, 2026-01-03 23:12:11),
            ('1', '1', '1', 3, 2026-01-03 23:12:12, 2026-01-03 23:12:12, 2026-01-04 23:12:11),
            ('1', '1', '1', 4, 2026-01-04 23:12:12, 2026-01-04 23:12:12, 2026-01-05 23:12:11),
            ('1', '1', '1', 3, 2026-01-05 23:12:12, 2026-01-05 23:12:12, None)

3. Single new row for a key. Insert the new row
   Target: -
   Source: ('6', '1', '1', 1, 2026-01-01 23:12:12)
   Result: ('6', '1', '1', 1, 2026-01-01 23:12:12, 2026-01-01 23:12:12, None)

4. Two new rows for the same key. Insert both rows with the earlier one being end dated by the later one
   Target: -
   Source: ('9', '1', '1', 1, 2026-01-01 12:12:12),
           ('9', '1', '1', 2, 2026-01-02 12:12:12)
   Result: ('9', '1', '1', 1, 2026-01-01 12:12:12, 2026-01-01 12:12:12, 2026-01-02 12:12:11),
           ('9', '1', '1', 2, 2026-01-02 12:12:12, 2026-01-02 12:12:12, None)

5. Source set has no change for a key. No update or insert is needed
   Target: ('3', '1', '1', 1, 2026-01-01 12:12:12, 2026-01-01 12:12:12, None),
           ('4', '1', '1', 1, 2026-01-01 12:12:12, 2026-01-01 12:12:12, None),
           ('5', '1', '1', 1, 2026-01-01 12:12:12, 2026-01-01 12:12:12, None),
           ('8', '1', '1', 1, 2026-01-01 12:12:12, 2026-01-01 12:12:12, None)
   Result: No change for these keys

6. Source set has duplicate rows for a given key. These rows should be ignored, no update or insert is needed
   Source: ('7', '1', '1', 1, 2026-01-01 12:12:12),
           ('7', '1', '1', 2, 2026-01-01 12:12:12)
   Result: -
'''

from pyspark.sql import SparkSession
from delta.pip_utils import configure_spark_with_delta_pip
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DateType, TimestampType
from datetime import date, datetime
from pathlib import Path

builder = SparkSession.builder.appName("MyApp") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.0.0")
spark = configure_spark_with_delta_pip(builder).getOrCreate()
spark.sparkContext.setLogLevel("OFF")

delta_path = "D:/Data/delta-lake/merge-incremental"
source_delta_table = "source_table"
target_delta_table = "target_table"

# Define source schema
schema = StructType([
 StructField("key1", StringType(), True),
 StructField("key2", StringType(), True),
 StructField("key3", StringType(), True),
 StructField("val1", IntegerType(), True),
 StructField("updated_at", TimestampType(), True),
 StructField("act", StringType(), True)
])
# Define source data
df_data =[('1','1','1',3,datetime.strptime("2026-01-03 23:12:12", '%Y-%m-%d %H:%M:%S'),"Update val to 3"),
          ('1','1','1',4,datetime.strptime("2026-01-04 23:12:12", '%Y-%m-%d %H:%M:%S'),"Update val to 4"),
          ('1','1','1',3,datetime.strptime("2026-01-05 23:12:12", '%Y-%m-%d %H:%M:%S'),"Update val to 3 again"),
          ('2','1','1',2,datetime.strptime("2026-01-02 12:12:12", '%Y-%m-%d %H:%M:%S'),"Update val to 2"),
          #('3','1','1',1,datetime.strptime("2026-01-03 12:12:12", '%Y-%m-%d %H:%M:%S'),"No change"),
          #('4','1','1',1,datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),"No change"),
          #('5','1','1',1,datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),"No change"),
          ('6','1','1',1,datetime.strptime("2026-01-01 23:12:12", '%Y-%m-%d %H:%M:%S'),"New row"),
          ('7','1','1',1,datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),"Duplicate, ignored"),
          ('7','1','1',1,datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),"Duplicate, ignored"),
          #('8','1','1',1,datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),"No change"),
          ('9','1','1',1,datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),"Two new inserts"),
          ('9','1','1',2,datetime.strptime("2026-01-02 12:12:12", '%Y-%m-%d %H:%M:%S'),"Two new inserts")]

df_source = spark.createDataFrame (df_data, schema=schema) # Create source dataframe
print ("Source dataframe:")
df_source.orderBy(["key1","updated_at"], ascending=[1,1]).show()
if spark.catalog.tableExists("src_tbl"): # Check if tempview exists
    spark.catalog.dropTempView ("src_tbl")

# Write as Delta table
df_source.write.format("delta").mode("overwrite").save(str (Path(delta_path) / source_delta_table))
df_lake_source= spark.read.format("delta").load(str (Path(delta_path) / source_delta_table))
df_lake_source.createTempView ("src_tbl")

# Define target schema (has start date and end date)
schema = StructType([
 StructField("key1", StringType(), True),
 StructField("key2", StringType(), True),
 StructField("key3", StringType(), True),
 StructField("val1", IntegerType(), True),
 StructField("updated_at", TimestampType(), True),
 StructField("start_date", TimestampType(), True),
 StructField("end_date", TimestampType(), True)
])
# Define target data
df_data =[('1','1','1',1,
           datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),
           datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),
           datetime.strptime("2026-01-02 22:12:11", '%Y-%m-%d %H:%M:%S')),
          ('1','1','1',2,
           datetime.strptime("2026-01-02 22:12:12", '%Y-%m-%d %H:%M:%S'),
           datetime.strptime("2026-01-02 22:12:12", '%Y-%m-%d %H:%M:%S'),
           None), # 1 has some history
          ('2','1','1',1,
           datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),
           datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),
           None),
          ('3','1','1',1,
           datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),
           datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),
           None),
          ('4','1','1',1,
           datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),
           datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),
           None),
          ('5','1','1',1,
           datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),
           datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),
           None),
          ('8','1','1',1,
           datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),
           datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),
           datetime.strptime("2026-01-02 22:12:11", '%Y-%m-%d %H:%M:%S')),
          ('8','1','1',2,
           datetime.strptime("2026-01-02 22:12:12", '%Y-%m-%d %H:%M:%S'),
           datetime.strptime("2026-01-02 22:12:12", '%Y-%m-%d %H:%M:%S'),
           None)]

df_target = spark.createDataFrame (df_data, schema=schema) # Create target dataframe
print ("Target dataframe:")
df_target.orderBy(["key1", "start_date"], ascending=[1, 1]).show()
if spark.catalog.tableExists("trg_tbl"): # Check if tempview exists
    spark.catalog.dropTempView ("trg_tbl")

#spark.sql("DELETE FROM delta.`D:/Data/DeltaLake/csaba_target`")
# Write as Delta table
df_target.write.format("delta").mode("overwrite").save(str (Path(delta_path) / target_delta_table))
df_lake_target = spark.read.format("delta").load(str (Path(delta_path) / target_delta_table))
df_lake_target.createTempView ("trg_tbl")

def merge (source_table: str, target_table: str, all_cols: list[str], partition_by_cols: list[str], primary_key: list[str], sort_col):
    select_cols = ", ".join ([f"{k}" for k in all_cols])
    merge_on = " AND ".join([f"trg.{k} = src.{k}" for k in partition_by_cols])
    part_by_cols = ", ".join ([f"{k}" for k in partition_by_cols])
    insert_cols = ", ".join ([f"src.{k}" for k in all_cols])
    primary_key_cols = ", ".join ([f"{k}" for k in primary_key])

    query = f"""
    MERGE INTO {target_table} AS trg
    USING (
    WITH ua AS (
        SELECT {select_cols},
               1 AS ind1,
               NULL AS ind2
        FROM   {source_table} 
        UNION ALL 
        SELECT {select_cols},
               NULL AS ind1,
               1 AS ind2
        FROM   {target_table} 
        WHERE  end_date IS NULL
    ),
    cnt AS (
        SELECT {select_cols},
               COUNT (ind1) OVER (PARTITION BY {part_by_cols}) AS cnt_ind1,
               COUNT (ind2) OVER (PARTITION BY {part_by_cols}) AS cnt_ind2
        FROM   ua
    )
    SELECT {select_cols},
           CASE WHEN cnt_ind1 > 0 AND cnt_ind2 = 0
                THEN 'I'
                WHEN cnt_ind1 = 0 AND cnt_ind2 = 1
                THEN 'U'
                ELSE '-'
           END AS transaction_type,
           updated_at AS start_date,
           LEAD ({sort_col} - interval '1' second) OVER (PARTITION BY {primary_key_cols} ORDER BY {sort_col}) AS end_date,
           COUNT (*) OVER (PARTITION BY {primary_key_cols}) AS row_cnt,
           COUNT (*) OVER (PARTITION BY {select_cols}) AS dupe_cnt
    FROM   cnt
    WHERE  cnt_ind1 != cnt_ind2) AS src
    ON     {merge_on}
           AND src.transaction_type = 'U' 
    WHEN MATCHED AND trg.end_date IS NULL 
           THEN UPDATE SET end_date = CASE WHEN src.row_cnt > 1 
                                           THEN src.end_date
                                      END
    WHEN NOT MATCHED AND transaction_type = 'I' AND src.dupe_cnt = 1
           THEN INSERT ({select_cols}, start_date, end_date) 
                VALUES ({insert_cols}, src.start_date, src.end_date) 
    ;
    """
    print("Merge query: \n", query)
    spark.sql (query).show ()  # Run the query and Show overall statistics of the merge

source_table = "src_tbl"
target_table = "trg_tbl"
all_cols = ["key1", "key2", "key3", "val1", "updated_at"]
partition_by_cols = ["key1", "key2", "key3", "val1"]
primary_key = ["key1", "key2", "key3"]
sort_col = "updated_at"

print("Merging...")
merge (source_table, target_table, all_cols, partition_by_cols, primary_key, sort_col)

# After the merge, read the target table to see the updated data
df = spark.read.format("delta").load(str(Path(delta_path) / target_delta_table))
print("Updated target dataframe:")
df.orderBy(["key1", "start_date"], ascending=[1, 1]).show()

exit (0)

'''
    MERGE INTO {target_table} AS trg
    USING (
    WITH ua AS (
        SELECT key1, key2, key3, val1, updated_at,
               1 AS ind1,
               NULL AS ind2                                                             -- Present in source
        FROM   {source_table} 
        UNION ALL 
        SELECT key1, key2, key3, val1, updated_at,
               NULL AS ind1,
               1 AS ind2                                                                -- Present in target
        FROM   {target_table} 
        WHERE  end_date IS NULL                                                         -- Current rows only (no end date)
    ),
    cnt AS (
        SELECT key1, key2, key3, val1, updated_at,
               COUNT (ind1) OVER (PARTITION BY key1, key2, key3, val1) AS cnt_ind1,     -- Without updated_at. Mark where row exists (source, target, both)
               COUNT (ind2) OVER (PARTITION BY key1, key2, key3, val1 AS cnt_ind2
        FROM   ua
    )
    SELECT key1, key2, key3, val1, updated_at,
           CASE WHEN cnt_ind1 > 0 AND cnt_ind2 = 0                                      -- Single or multiple rows exist in source
                THEN 'I'
                WHEN cnt_ind1 = 0 AND cnt_ind2 = 1                                      -- Row exists in target only (no change)
                THEN 'U'
                ELSE '-'                                                                -- Same row exists in both source and target or duplicates exist in source
           END AS transaction_type,
           updated_at AS start_date,
           LEAD ({sort_col} - interval '1' second) OVER (PARTITION BY key1, key2, key3 ORDER BY {sort_col}) AS end_date, # Set start/end date order for multiple rows in source
           COUNT (*) OVER (PARTITION BY key1, key2, key3 AS row_cnt,                    -- Count rows under this key. End date row only if there exist at least one source row
           COUNT (*) OVER (PARTITION BY key1, key2, key3, val1, updated_at AS dupe_cnt  -- Insert new rows only if they are not dupes
    FROM   cnt
    WHERE  cnt_ind1 != cnt_ind2) AS src                                                 -- If counts are equal, there is no change
    ON     {merge_on}
           AND src.transaction_type = 'U' 
    WHEN MATCHED AND trg.end_date IS NULL                                               -- End date only if a replacing row exists in source
           THEN UPDATE SET end_date = CASE WHEN src.row_cnt > 1                         -- There is at least one source row besides the target row (row_cnt > 1)
                                           THEN src.end_date
                                      END
    WHEN NOT MATCHED AND transaction_type = 'I' AND src.dupe_cnt = 1                    -- Insert only if the source row is not a duplicate
           THEN INSERT (key1, key2, key3, val1, updated_at, start_date, end_date) 
                VALUES (src.key1, src.key2, src.key3, src.val1, src.updated_at, src.start_date, src.end_date) 
    ;

'''
