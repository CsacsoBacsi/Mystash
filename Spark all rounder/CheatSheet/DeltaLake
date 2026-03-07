import pyspark
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, ArrayType, MapType
from pyspark.sql.functions import col, struct, when
from delta import *
from delta.tables import DeltaTable

# Setup DL
conf = (
    pyspark.conf.SparkConf ()
    .setAppName ("MyApp")
    .set (
        "spark.sql.catalog.spark_catalog",
        "org.apache.spark.sql.delta.catalog.DeltaCatalog",
    )
    .set ("spark.hadoop.fs.gs.impl", "com.google.cloud.hadoop.fs.gcs.GoogleHadoopFileSystem")
    .set ("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
    .set ("spark.hadoop.fs.gs.impl", "com.google.cloud.hadoop.fs.gcs.GoogleHadoopFileSystem")
    .set ("spark.hadoop.google.cloud.auth.service.account.enable", "true")
    .set ("spark.hadoop.google.cloud.auth.service.account.json.keyfile", "/Users/rpelgrim/Desktop/gcs.json")
    .set ("spark.sql.shuffle.partitions", "4")
    .set ("spark.jars", "https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop3-latest.jar") \
    .setMaster (
        "local[*]"
    )  # replace the * with your desired number of cores. * to use all.
)

builder = pyspark.sql.SparkSession.builder.appName ("MyApp").config (conf=conf)
spark = configure_spark_with_delta_pip (builder).getOrCreate ()

# Write to DL
data = spark.range (0, 5)
#data.write.format ("delta").mode("overwrite").save ("gs://spark_cr2/delta-table")
data.write.format ("delta").mode("overwrite").save ("C:/Users/csacs/delta/delta-table")

# Read it back
df = spark.read.format("delta").load ("C:/Users/csacs/delta/delta-table")
df.show()

deltaTable = DeltaTable.forPath (spark, "C:/Users/csacs/delta/delta-table")

# Update rows where id is less than 2
deltaTable.update("id < 2", {"id": "id + 10"})

# Delete rows where id equals 4
deltaTable.delete("id = 4")

df = spark.read.format("delta").load ("C:/Users/csacs/delta/delta-table")
print ("DataFrame:")
df.show ()
#print ("DeltaLake table:")
#DeltaTable.show ()

# Merge on ID
new_data = spark.range(0, 20)
deltaTable.alias ("old").merge (new_data.alias ("new"),
    "old.id = new.id"
).whenMatchedUpdate (set = {"id": "new.id"}).whenNotMatchedInsert (values={"id": "new.id"}).execute ()

df = spark.read.format("delta").load ("C:/Users/csacs/delta/delta-table")
df.show()
