from pyspark.sql import SparkSession
from delta.pip_utils import configure_spark_with_delta_pip
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DateType, TimestampType
from datetime import date
from delta.tables import DeltaTable
from pyspark.sql.functions import lit
from pyspark.sql import functions as sf
from pyspark.sql.functions import when, col

builder = SparkSession.builder.appName("MyApp") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.0.0")
spark = configure_spark_with_delta_pip(builder).getOrCreate()
spark.sparkContext.setLogLevel("OFF")

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

sourceDF = spark.createDataFrame (df_data, schema=schema) # Create source dataframe
sourceDF = sourceDF.withColumns ({"ind1": lit(1), "ind2": lit(None)})
print ("Source dataframe:")
sourceDF.orderBy(["col1"], ascending=[1]).show()
if spark.catalog.tableExists("csaba_src"): # Check if tempview exists
    spark.catalog.dropTempView ("csaba_src")
# Write as Delta table
#source.write.format("delta").mode("overwrite").save("D:/Data/DeltaLake/csaba_source")
# = spark.read.format("delta").load("D:/Data/DeltaLake/csaba_source")

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
targetDF = spark.createDataFrame (df_data, schema=schema)
targetDF = targetDF.withColumns ({"ind1": lit(None), "ind2": lit(1)})
print ("Target dataframe:")
targetDF.orderBy(["col1", "start_date"], ascending=[1, 1]).show()

# Write as Delta table
targetDF.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("D:/Data/DeltaLake/csaba_target")
targetDF = spark.read.format("delta").load("D:/Data/DeltaLake/csaba_target")

# Merge preparation: source data
unionDF = sourceDF.unionByName(targetDF.filter ("end_date is null"), allowMissingColumns=True)
actionDF = unionDF.groupBy ('col1','col2','col3','val') \
       .agg(sf.count("ind1").alias("ind1_count"), sf.count("ind2").alias("ind2_count")) \
       .filter ("ind1_count <> ind2_count") \
       .withColumn("tx_type"
                   ,when ((col ("ind2_count") == 0) & (col ("ind1_count") == 1), "I")
                   .when ((col ("ind1_count") == 0) & (col ("ind2_count") == 1), "U")
                   .otherwise ("Q"))
unwanted_cols = ["ind1_count", "ind2_count", "ind1", "ind2"]
actionDF = actionDF.drop (*unwanted_cols)
actionDF.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("D:/Data/DeltaLake/csaba_action")
actionDF = spark.read.format("delta").load("D:/Data/DeltaLake/csaba_action")
print ("Action dataframe:")
actionDF.show ()                                                 
# Source must be a dataframe, not DeltaLake table
targetDF = targetDF.drop (*('ind1','ind2'))
targetDF.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("D:/Data/DeltaLake/csaba_target")
targetDT = DeltaTable.forPath(spark, 'D:/Data/DeltaLake/csaba_target')
print ("Target dataframe:")

targetDT.toDF().show ()
actionDF.show () 

# Merge preparation: join, update, insert condition
join_condition = "target.col1 = source.col1 AND source.tx_type = 'U'"
cols_to_check = ["col2", "col3", "val"]
update_condition = "target.end_date is null"
insert_values = {c: f"source.{c}" for c in cols_to_check}
update_set = {"end_date": "current_date -1"}
insert_condition = "source.tx_type = 'I'"
insert_values["col1"] = "source.col1"
insert_values["start_date"] = "current_date"

print ("Join condition: " + join_condition)
print ("Update_condition: " + update_condition)
print ("Update set: " + str (update_set))
print ("Insert condition: " + insert_condition)

# Multiple source rows can not be used to update a single target row. How does the system know which source row to use for update?
(
    targetDT.alias("target")
    .merge(actionDF.alias("source"), join_condition)
    .whenMatchedUpdate(condition=update_condition, set=update_set)
    .whenNotMatchedInsert(condition=insert_condition, values=insert_values)
    .execute()
)

df = targetDT.toDF()
print ("Result dataframe:")
df.orderBy(["col1", "start_date"], ascending=[1, 1]).show()
df = df
sourceDF = sourceDF


