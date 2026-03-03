from pyspark.sql import SparkSession
from pyspark.sql.types import *
from pyspark.sql import Row

#log4j = sc._jvm.org.apache.log4j                                                                                                                                                                                          
#log4j.LogManager.getRootLogger().setLevel(log4j.Level.ERROR)

spark = SparkSession \
    .builder \
    .appName("Python Spark SQL basic example") \
    .config("spark.some.config.option", "some-value") \
    .getOrCreate()
spark.sparkContext.setLogLevel("ERROR")
sc = spark.sparkContext
sc.setLogLevel ("ERROR")

# Spark is an existing SparkSession
df = spark.read.json("/examples/src/main/resources/people.json")
# Displays the content of the DataFrame to stdout
print ("JSON file content:")
df.show()

print ("Schema:")
df.printSchema () ;
print ("Select names:")
df.select("name").show()
print ("Select names and age+1:")
df.select(df['name'], df['age'] + 1).show()
print ("Select ages above 21:")
df.filter(df['age'] > 21).show()
print ("Select GROUB BY age:")
df.groupBy("age").count().show()

# SQL to run against tables or temporary views
df.createOrReplaceTempView("people")
sqlDF = spark.sql("SELECT * FROM people")
print ("Select from tempoarary view created from DataFrame:")
sqlDF.show()

# Global - visible in all sessions
df.createGlobalTempView("people")
print ("Select from global temporary view:")
spark.sql("SELECT * FROM global_temp.people").show()

lines = sc.textFile ("/examples/src/main/resources/people.txt")
parts = lines.map (lambda l: l.split(","))
# Row is key-value pairs
people = parts.map (lambda p: Row(name=p[0], age=int(p[1])))

schemaPeople = spark.createDataFrame(people)
schemaPeople.createOrReplaceTempView("people")
teenagers = spark.sql("SELECT name FROM people WHERE age >= 13 AND age <= 19")
# The results of SQL queries are Dataframe objects.
print ("Select names where age > 13 and <= 19:")
teenNames = teenagers.rdd.map(lambda p: "Name: " + p.name).collect()
for name in teenNames:
    print(name)

# Define schema programmatically
people = parts.map(lambda p: (p[0], p[1].strip()))
schemaString = "name_col age_col"
fields = [StructField(field_name, StringType(), True) for field_name in schemaString.split()]
schema = StructType(fields)

schemaPeople = spark.createDataFrame(people, schema)
schemaPeople.createOrReplaceTempView("people")

results = spark.sql("SELECT name_col FROM people")
print ("Select from programmatically defined schema:")
results.show()

df = spark.read.load("/examples/src/main/resources/people.json", format="json")
#df.select("name", "age").write.save("/examples/src/main/resources/namesAndAges.parquet", format="parquet")

df = spark.sql("SELECT * FROM parquet.`/examples/src/main/resources/users.parquet`")
df.show ()

