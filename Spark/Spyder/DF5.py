# ***********************************
# *** DataFrame column operations ***
# ***********************************

import pyspark
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit
from pyspark.sql.types import StructType, StructField, StringType,IntegerType

spark = SparkSession.builder.appName('SparkByExamples.com').getOrCreate ()

data = [('James','','Smith','1991-04-01','M',3000),
  ('Michael','Rose','','2000-05-19','M',4000),
  ('Robert','','Williams','1978-09-05','M',4000),
  ('Maria','Anne','Jones','1967-12-01','F',4000),
  ('Jen','Mary','Brown','1980-02-17','F',-1)
]

columns = ["firstname","middlename","lastname","dob","gender","salary"]
df = spark.createDataFrame (data=data, schema = columns)
df.printSchema ()
df.show (truncate = False)

# Change column datatype
df2 = df.withColumn ("salary", col ("salary").cast ("Integer"))
df2.printSchema ()
df2.show (truncate=False)

# Update column value
df3 = df.withColumn ("salary",col("salary")*100)
df3.printSchema ()
df3.show (truncate = False) 

# Copy from existing column but invert its sign
df4 = df.withColumn ("CopiedColumn",col("salary") * -1)
df4.printSchema ()

df5 = df.withColumn ("Country", lit("USA"))
df5.printSchema ()

df6 = df.withColumn ("Country", lit("USA")).withColumn ("anotherColumn",lit("anotherValue"))
df6.printSchema ()
df6.show (truncate = False) 

# Rename
df.withColumnRenamed("gender","sex").show (truncate = False) 
# Transformation. Returns new DF without the column but original DF is intact
df4.drop ("CopiedColumn").show (truncate = False)
df4.show (truncate = False) 

df.withColumnRenamed ("dob","DateOfBirth").printSchema ()
df2 = df.withColumnRenamed ("dob","DateOfBirth") \
    .withColumnRenamed ("salary","salary_amount")
df2.printSchema ()

# Struct rename
schema = StructType([
    StructField('name', StructType([
         StructField('firstname', StringType(), True),
         StructField('middlename', StringType(), True),
         StructField('lastname', StringType(), True)
         ])),
          StructField('dob', StringType(), True),
         StructField('gender', StringType(), True),
         StructField('salary', StringType(), True)
     ])
data = [(("Anna","Rose",""),"2022-07-08","M","100M")]

df2 = spark.createDataFrame (data = data, schema = schema)

schema2 = StructType([
    StructField("fname",StringType()),
    StructField("middlename",StringType()),
    StructField("lname",StringType())])

df22 = df2.select (col ("name").cast (schema2), \
     col ("dob"), col ("gender"),col ("salary"))
df22.printSchema ()

df22.select (col ("name.fname").alias ("first_name"), \
  col ("name.middlename").alias ("middle_name"), \
  col ("name.lname").alias ("last_name"), \
  col ("dob"),col ("gender"),col ("salary")).printSchema ()
# withColumn
df4 = df2.withColumn("firstname",col("name.firstname")) \
      .withColumn("middlename",col("name.middlename")) \
      .withColumn("lastname",col("name.lastname")) \
      .drop("name")
df4.printSchema()