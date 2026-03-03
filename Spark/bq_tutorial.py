from pyspark.sql import SparkSession

print ("")
print ("***** Spark BigQuery connector tutorial *****")
print ("")
spark = SparkSession \
  .builder \
  .master ('yarn') \
  .appName ('spark-bigquery-connector') \
  .getOrCreate ()

# Spark Context
sc = spark.sparkContext
print ("# Spark context: " + str (sc))
print ("# Spark App Name: " + sc.appName)
print ("# Cluster version: " + sc.version)
print ("# Application ID: " + sc.applicationId)

# Set temporary GCS bucket
bucket = 'bq_temp_cr2'
spark.conf.set ("temporaryGcsBucket", bucket)

spark.conf.set ("viewsEnabled","true")
spark.conf.set ("materializationDataset","spark")

# Load BQ table into DF
print ("# Dataframe load from sql query")
sql = """
  SELECT id, volume 
  FROM `project-16-462414.spark.table1` 
  """
volsDF = spark.read.format ('bigquery').load(sql)
volsDF.show ()

print ("# Dataframe load from table")
volsDF = spark.read.format ('bigquery') \
  .option ('table', 'project-16-462414:spark.table1') \
  .load ()
volsDF.show ()
print ("Show id column 1")
volsDF.select ("id").show ()

# Create temp view so that Spark SQL can be used on the DF
volsDF.createOrReplaceTempView ("vols")

volCountDF = spark.sql ('SELECT id, SUM (volume) AS sum_vol FROM vols GROUP BY id')
print ("# Show id column 2")
volCountDF.select ("id").show ()
print ("# Show full dataframe")
volCountDF.show ()
print ("# Show schema")
volCountDF.printSchema ()

# Write to BigQuery
print ("# Write to BigQuery")
volCountDF.write.format ('bigquery').option ("writeMethod", "direct")
volCountDF.write.format ('bigquery').option ('table','spark.volcount_output').save (mode='overwrite')

'''
final_df.write.format ("bigquery") \
            .option ("table", "<your_project_id>.<your_dataset>.<your_table>")
            .option ("temporaryGcsBucket", c.TEMPORARY_GCS_BUCKET) \
            .option ("table", self.gbq_project + ":" + final_dataset_name + "." + output_short_table_name) \
            .option ("createDisposition", "CREATE_IF_NEEDED") \
            .option ("schemaUpdateOptions", "ALLOW_FIELD_ADDITION" if use_gbq_overwrite_mode else '') \
            .option ("decimal", "NUMERIC") \
            .option ("partitionField", partition_column) \
            .option ("partitionType", "DAY") \
            .mode ('overwrite' if use_gbq_overwrite_mode else 'append') \
            .save ()
'''