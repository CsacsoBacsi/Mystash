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

delta_path = "C:/Work/delta-lake"
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
          ('2','1','1',2,datetime.strptime("2026-01-02 12:12:12", '%Y-%m-%d %H:%M:%S'),"Update val to 2"),
          ('3','1','1',1,datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),"No change"),
          ('4','1','1',1,datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),"No change"),
          ('6','1','1',1,datetime.strptime("2026-01-01 23:12:12", '%Y-%m-%d %H:%M:%S'),"New row, 5 deleted"),
          ('7','1','1',1,datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),"Duplicate, ignored"), # Multiple source rows can not update a single target row!
          ('7','1','1',1,datetime.strptime("2026-01-01 12:12:12", '%Y-%m-%d %H:%M:%S'),"Duplicate, ignored")]

df_source = spark.createDataFrame (df_data, schema=schema) # Create source dataframe
print ("Source dataframe:")
df_source.orderBy(["key1"], ascending=[1]).show()
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

def merge (source_table: str, target_table: str, table_cols: list[str], primary_key: list[str], sort_col):
    select_cols = ", ".join ([f"{k}" for k in table_cols])
    merge_on = " AND ".join([f"trg.{k} = src.{k}" for k in table_cols])
    insert_cols = ", ".join ([f"src.{k}" for k in table_cols])
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
               COUNT (ind1) OVER (PARTITION BY {select_cols} ORDER BY {sort_col}) AS cnt_ind1,
               COUNT (ind2) OVER (PARTITION BY {select_cols} ORDER BY {sort_col}) AS cnt_ind2
        FROM   ua
    )
    SELECT {select_cols},
           CASE WHEN cnt_ind1 = 1 AND cnt_ind2 = 0
                THEN 'I'
                WHEN cnt_ind1 = 0 AND cnt_ind2 = 1
                THEN 'U'
                ELSE '-'
           END AS transaction_type,
           updated_at AS start_date,
           LEAD ({sort_col} - interval '1' second) OVER (PARTITION BY {primary_key_cols} ORDER BY {sort_col}) AS end_date,
           COUNT (*) OVER (PARTITION BY {primary_key_cols}) AS row_cnt
    FROM   cnt
    WHERE  cnt_ind1 != cnt_ind2) AS src
    ON     {merge_on}
           AND src.transaction_type = 'U' 
    WHEN MATCHED AND trg.end_date IS NULL 
           THEN UPDATE SET end_date = CASE WHEN src.row_cnt = 1 
                                           THEN DATE_TRUNC ('second', current_timestamp) 
                                           ELSE src.end_date
                                      END
    WHEN NOT MATCHED AND transaction_type = 'I' 
           THEN INSERT ({select_cols}, start_date, end_date) 
                VALUES ({insert_cols}, src.start_date, src.end_date) 
    ;
    """

    print ("Merging...")
    print ("Merge query: \n", query)

    spark.sql (query).show ()  # Run the query and Show overall statistics of the merge

    df = spark.read.format("delta").load(str (Path(delta_path) / target_delta_table))
    print ("Updated target dataframe:")
    df.orderBy(["key1", "start_date"], ascending=[1, 1]).show()

source_table = "src_tbl"
target_table = "trg_tbl"
table_cols = ["key1", "key2", "key3", "val1", "updated_at"]
primary_key = ["key1", "key2", "key3"]
sort_col = "updated_at"
merge (source_table, target_table, table_cols, primary_key, sort_col)
