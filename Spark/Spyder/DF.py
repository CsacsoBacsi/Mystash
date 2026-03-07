# *********************************
# *** Create DataFrame from RDD ***
# *********************************

from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, ArrayType, MapType
from pyspark.sql.functions import col, struct, when

spark = SparkSession.builder.appName ('Spark DF').getOrCreate ()

# Creates Empty RDD
emptyRDD = spark.sparkContext.emptyRDD ()
print (emptyRDD)

schema = StructType([
  StructField('firstname', StringType(), True),
  StructField('middlename', StringType(), True),
  StructField('lastname', StringType(), True)
  ])
# Create empty DataFrame from empty RDD
df = spark.createDataFrame(emptyRDD,schema)
df.printSchema ()

# Convert empty RDD to Dataframe
df1 = emptyRDD.toDF (schema)
df1.printSchema ()

# Create empty DataFrame directly.
df2 = spark.createDataFrame ([], schema)
df2.printSchema ()

# Create DataFrame from RDD
dept = [("Finance",10),("Marketing",20),("Sales",30),("IT",40)]
rdd = spark.sparkContext.parallelize (dept)
df = rdd.toDF ()
df.printSchema ()
df.show (truncate = False)
# Create DataFrame from RDD with column names
deptColumns = ["dept_name","dept_id"]
df2 = rdd.toDF (deptColumns)
df2.printSchema ()
df2.show (truncate = False)

deptDF = spark.createDataFrame(rdd, schema = deptColumns)
deptDF.printSchema()
deptDF.show(truncate = False)

deptSchema = StructType([       
    StructField('dept_name', StringType(), True),
    StructField('dept_id', StringType(), True)
])

deptDF1 = spark.createDataFrame (rdd, schema = deptSchema)
deptDF1.printSchema ()
deptDF1.show (truncate = False)

# Create Pandas DF (des not run parallel) from nested structure
dataStruct = [(("James","","Smith"),"36636","M","3000"), \
      (("Michael","Rose",""),"40288","M","4000"), \
      (("Robert","","Williams"),"42114","M","4000"), \
      (("Maria","Anne","Jones"),"39192","F","4000"), \
      (("Jen","Mary","Brown"),"","F","-1") \
]

schemaStruct = StructType([
        StructField('name', StructType([
             StructField('firstname', StringType(), True),
             StructField('middlename', StringType(), True),
             StructField('lastname', StringType(), True)
             ])),
          StructField('dob', StringType(), True),
         StructField('gender', StringType(), True),
         StructField('salary', StringType(), True)
         ])
df = spark.createDataFrame (data=dataStruct, schema = schemaStruct)
df.printSchema ()

pandasDF2 = df.toPandas ()
print (pandasDF2)

# Default - displays 20 rows and 
# 20 charactes from column value 
df.show()
# Display full column contents
df.show(truncate=False)
# Display 2 rows and full column contents
df.show(2,truncate=False) 
# Display 2 rows & column values 25 characters
df.show(2,truncate=25) 
# Display DataFrame rows & columns vertically
df.show(n=3,truncate=25,vertical=True)

# With column. Replace last 3 columns with a new struct column that has them
# col returns a column object by name. when also returns a column (case statement)
# Drop deletes the columns
print ("# With column")
updatedDF = df.withColumn("OtherInfo", 
    struct(col("dob").alias("dob"),
    col("gender").alias("gender"),
    col("salary").alias("salary"),
    when(col("salary").cast(IntegerType()) < 2000,"Low")
      .when(col("salary").cast(IntegerType()) < 4000,"Medium")
      .otherwise("High").alias("Salary_Grade")
  )).drop("dob","gender","salary")

updatedDF.printSchema ()
updatedDF.show (truncate=False)

# Add or update column in a DF
dfwith = spark.createDataFrame([(2, "Alice"), (5, "Bob")], schema=["age", "name"])
dfwith.withColumn ('age2', dfwith.age + 2).show ()

# Using SQL ArrayType and MapType
arrayStructureSchema = StructType([
    StructField('name', StructType([
       StructField('firstname', StringType(), True),
       StructField('middlename', StringType(), True),
       StructField('lastname', StringType(), True)
       ])),
       StructField('hobbies', ArrayType(StringType()), True),
       StructField('properties', MapType(StringType(),StringType()), True)
    ])

# Check if a column exists
if "firstname" in df.columns:
    print("Column 'firstname' exists in the DataFrame.")
else:
    print("Column 'firstname' does not exist in the DataFrame.")
