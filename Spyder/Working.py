from pyspark.sql import SparkSession
from delta.pip_utils import configure_spark_with_delta_pip
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DateType
from datetime import date

builder = SparkSession.builder.appName("MyApp") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.0.0")
spark = configure_spark_with_delta_pip(builder).getOrCreate()
spark.sparkContext.setLogLevel("OFF")

# Define target schema (has start date and end date)
schema = StructType([
 StructField("col1", StringType(), True), 
 StructField("col2", StringType(), True),
 StructField("col3", StringType(), True),
 StructField("val", IntegerType(), True),
 StructField("start_date", DateType(), True),
 StructField("end_date", DateType(), True)
])
# Define target data
df_data =[('1','1','1',1,date.fromisoformat('2019-01-01'),date.fromisoformat('2025-03-31')), 
          ('1','1','1',2,date.fromisoformat('2025-04-01'),None), # 1 has some history
          ('2','1','1',1,date.fromisoformat('2019-01-01'),None),
          ('3','1','1',1,date.fromisoformat('2019-01-01'),None),
          ('4','1','1',1,date.fromisoformat('2019-01-01'),None),
          ('5','1','1',1,date.fromisoformat('2019-01-01'),None)]
df_target = spark.createDataFrame (df_data, schema=schema) # Create target dataframe
print ("Target dataframe:")
df_target.orderBy(["col1", "start_date"], ascending=[1, 1]).show()
if spark.catalog.tableExists("csaba_trg"): # Check if tempview exists
    spark.catalog.dropTempView ("csaba_trg")

#spark.sql("DELETE FROM delta.`D:/Data/DeltaLake/csaba_target`")
# Write as Delta table
df_target.write.format("delta").mode("overwrite").save("D:/Data/DeltaLake/csaba_target")
df_lake_target = spark.read.format("delta").load("D:/Data/DeltaLake/csaba_target")
df_lake_target.createTempView ("csaba_trg")

# Define source schema
schema = StructType([
 StructField("col1", StringType(), True), 
 StructField("col2", StringType(), True),
 StructField("col3", StringType(), True),
 StructField("val", IntegerType(), True),
 StructField("act", StringType(), True)
])
# Define source data
df_data =[('1','1','1',3,"Update val to 3"),
          ('2','1','1',2,"Update val to 2"),
          ('3','1','1',1,"No change"),
          ('4','1','1',1,"No change"),
          ('6','1','1',1,"New row, 5 deleted"),
          ('7','1','1',1,"Duplicate, ignored"), # Multiple source rows can not update a single target row!
          ('7','1','1',1,"Duplicate, ignored")]

df_source = spark.createDataFrame (df_data, schema=schema) # Create source dataframe
print ("Source dataframe:")
df_source.orderBy(["col1"], ascending=[1]).show()
if spark.catalog.tableExists("csaba_src"): # Check if tempview exists
    spark.catalog.dropTempView ("csaba_src")

# Write as Delta table
df_source.write.format("delta").mode("overwrite").save("D:/Data/DeltaLake/csaba_source")
df_lake_source= spark.read.format("delta").load("D:/Data/DeltaLake/csaba_source")
df_lake_source.createTempView ("csaba_src")

print ("Merge result:")

"""
insert into csaba_trg (col1, col2, col3, val, updated_at, start_date, end_date)
values ('1','1','1',1, '2026-01-01 12:12:12', '2026-01-01 12:12:12',  '2026-01-02 22:12:11') ;
insert into csaba_trg (col1, col2, col3, val, updated_at, start_date, end_date)
values ('1','1','1',2, '2026-01-02 22:12:12', '2026-01-02 22:12:12', NULL) ;
insert into csaba_trg (col1, col2, col3, val, updated_at, start_date, end_date)
values ('2','1','1',1, '2026-01-01 12:12:12', '2026-01-01 12:12:12', NULL) ;
insert into csaba_trg (col1, col2, col3, val, updated_at, start_date, end_date)
values ('3','1','1',1, '2026-01-01 12:12:12', '2026-01-01 12:12:12', NULL) ;
insert into csaba_trg (col1, col2, col3, val, updated_at, start_date, end_date)
values ('4','1','1',1, '2026-01-01 12:12:12', '2026-01-01 12:12:12', NULL) ;
insert into csaba_trg (col1, col2, col3, val, updated_at, start_date, end_date)
values ('5','1','1',1, '2026-01-01 12:12:12', '2026-01-01 12:12:12', NULL) ;
insert into csaba_trg (col1, col2, col3, val, updated_at, start_date, end_date)
values ('8','1','1',1, '2026-01-01 12:12:12', '2026-01-01 12:12:12',  '2026-01-02 22:12:11') ;
insert into csaba_trg (col1, col2, col3, val, updated_at, start_date, end_date)
values ('8','1','1',2, '2026-01-02 22:12:12', '2026-01-02 22:12:12', NULL) ;

commit ;

-- 1 is deleted, so Update
insert into csaba_src (col1, col2, col3, val, updated_at)
values ('1','1','1',3,'2026-01-03 23:12:12') ; -- New row, INSERT
insert into csaba_src (col1, col2, col3, val, updated_at)
values ('2','1','1',2, '2026-01-02 22:12:12') ; -- Update val
insert into csaba_src (col1, col2, col3, val, updated_at)
values ('3','1','1',1, '2026-01-01 12:12:12') ; -- Nothing here
insert into csaba_src (col1, col2, col3, val, updated_at)
values ('4','1','1',1, '2026-01-01 12:12:12') ; -- Nothing here
-- 5 is deleted, so Update
insert into csaba_src (col1, col2, col3, val, updated_at) -- New row, INSERT
values ('6','1','1',1, '2026-01-01 23:12:12') ;
insert into csaba_src (col1, col2, col3, val, updated_at) -- Duplicate. Must be ignored
values ('7','1','1',1, '2026-01-01 12:12:12') ;
insert into csaba_src (col1, col2, col3, val, updated_at)
values ('7','1','1',1, '2026-01-01 12:12:12') ;
-- 8 is deleted, so Update
commit ;

select * from csaba_trg order by col1, start_date ;
"""
spark.sql ("""
MERGE INTO csaba_trg AS trg
USING (
WITH ua AS (
    SELECT col1, col2, col3, val, updated_at,
           1 AS ind1,
           NULL AS ind2
    FROM   csaba_src 
    UNION ALL 
    SELECT col1, col2, col3, val, updated_at,
           NULL AS ind1,
           1 AS ind2
    FROM   csaba_trg 
    WHERE  end_date IS NULL
),
cnt AS (
    SELECT col1, col2, col3, val, updated_at,
           ind1, ind2,
           COUNT (ua.ind1) OVER (PARTITION BY col1, col2, col3, val ORDER BY updated_at) AS cnt_ind1,
           COUNT (ua.ind2) OVER (PARTITION BY col1, col2, col3, val ORDER BY updated_at) AS cnt_ind2
    FROM   ua
)
SELECT ua.col1, ua.col2, ua.col3, ua.val, ua.updated_at,
       CASE WHEN ua.cnt_ind1 = 1 AND ua.cnt_ind2 = 0
            THEN 'I'
            WHEN ua.cnt_ind1 = 0 AND ua.cnt_ind2 = 1
            THEN 'U'
            ELSE '-'
       END AS transaction_type,
       updated_at AS start_date,
       LEAD (updated_at - interval '1' second) OVER (PARTITION BY col1 ORDER BY updated_at) AS end_date,
       COUNT (col1) OVER (PARTITION BY col1, col2, col3) AS row_cnt
FROM   ua
WHERE  ua.cnt_ind1 != ua.cnt_ind2) ) AS src
ON     trg.col1 = src.col1 
   AND trg.col2 = src.col2
   AND trg.col3 = src.col3
   AND src.transaction_type = 'U' 
WHEN MATCHED AND trg.end_date IS NULL 
       THEN UPDATE SET end_date = CASE WHEN row_cnt = 1 
	                               THEN DATE_TRUNC ('second', current_timestamp) 
                                       ELSE src.end_date
                                  END
WHEN NOT MATCHED AND transaction_type = 'I' 
       THEN INSERT (col1, col2, col3, val, updated_at, start_date, end_date) 
            VALUES (src.col1, src.col2, src.col3, src.val, src.updated_at, src.start_date, src.end_date) 
;

select * from csaba_trg order by col1, start_date ;
"""
).show () # Show overall statistics of the merge

df = spark.read.format("delta").load("D:/Data/DeltaLake/csaba_target")
print ("Updated target dataframe:")
df.orderBy(["col1", "start_date"], ascending=[1, 1]).show()
