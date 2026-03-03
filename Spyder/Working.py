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

# Define target schema (has start and end date)
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
spark.sql (
"""
MERGE INTO csaba_trg AS t USING
    (WITH ua AS ( 
        SELECT col1, col2, col3, val,
               1 AS ind1, -- Exists in source
               NULL AS ind2
        FROM   csaba_src 
        WHERE  1=1  
        UNION ALL 
        SELECT col1, col2, col3, val, 
               NULL AS ind1,
               1 AS ind2 -- Exists in target
        FROM   csaba_trg 
        WHERE  end_date IS NULL  
    )
    SELECT ua.col1, ua.col2, ua.col3, ua.val, 
           CASE WHEN COUNT (ua.ind2) = 0 AND COUNT (ua.ind1) = 1 THEN 'I' -- Row in source not in target, e.g. new row (needs inserting)
                WHEN COUNT (ua.ind1) = 0 AND COUNT (ua.ind2) = 1 THEN 'U' -- Row in target not in source, e.g. deleted row (needs end dating)
                ELSE                                                  'Q' -- 1 on both sides means no change, e.g. same row If more than 1, it means dupes present
            END AS transaction_type, 
            COUNT (ua.ind1) count_ind1, -- For recon and testing purposes only
            COUNT (ua.ind2) count_ind2, -- For recon and testing purposes only
            current_date as start_date,
            current_date -1 as end_date 
    FROM  ua 
    GROUP BY ua.col1, ua.col2, ua.col3, ua.val # Check all columns if they are different. Basically distinct list
    HAVING COUNT (ua.ind1) != COUNT (ua.ind2)) AS src # Only when there is a difference. Otherwise no change, so ignore
ON (t.col1 || '||' || t.col2 || '||' || t.col3 || '||' || 'U' = 
    src.col1 || '||' || src.col2 || '||' || src.col3 || '||' || src.transaction_type) # Merge key: primary key columns
WHEN MATCHED AND t.end_date IS NULL THEN # There can be a multi-row history for a key, so leave those rows and operate on current/live row only
    UPDATE SET end_date = src.end_date # Update only the end date (close row off). New data will be inserted.
WHEN NOT MATCHED AND transaction_type = 'I' THEN # Row of type 'I' is only present in target, so insert
    INSERT (col1, col2, col3, val, start_date, end_date) 
    VALUES (src.col1, src.col2, src.col3, src.val, src.start_date, NULL) 
"""
).show () # Show overall statistics of the merge

df = spark.read.format("delta").load("D:/Data/DeltaLake/csaba_target")
print ("Updated target dataframe:")
df.orderBy(["col1", "start_date"], ascending=[1, 1]).show()

