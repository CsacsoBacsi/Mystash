import pyspark
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName ('SparkByExamples.com').getOrCreate ()

# Data
data = [("James","Smith","USA","CA"),
    ("Michael","Rose","USA","NY"),
    ("Robert","Williams","USA","CA"),
    ("Maria","Jones","USA","FL")
  ]

# Column names
columns = ["firstname","lastname","country","state"]

# Create DataFrame
df = spark.createDataFrame (data = data, schema = columns)
df.show (truncate = False)

# Select columns by different ways
df.select ("firstname","lastname").show ()
df.select (df.firstname,df.lastname).show ()
df.select(df["firstname"],df["lastname"]).show ()

# By using col() function
from pyspark.sql.functions import col
df.select (col("firstname"),col("lastname")).show ()

# Select columns by regular expression
df.select (df.colRegex("`^.*name*`")).show ()

# Select All columns from List
df.select (*columns).show ()
df.select ([col for col in df.columns]).show ()
df.select ("*").show ()

# Selects first 3 columns and top 3 rows
df.select (df.columns[:3]).show (3)
#Selects columns 2 to 4  and top 3 rows not including second column
df.select (df.columns[2:4]).show (3)

# Select struct columns, fields
# Create DataFrame with nested columns
data = [
        (("James",None,"Smith"),"OH","M"),
        (("Anna","Rose",""),"NY","F"),
        (("Julia","","Williams"),"OH","F"),
        (("Maria","Anne","Jones"),"NY","M"),
        (("Jen","Mary","Brown"),"NY","M"),
        (("Mike","Mary","Williams"),"OH","M")
        ]

from pyspark.sql.types import StructType,StructField, StringType        
schema = StructType([
    StructField('name', StructType([
         StructField('firstname', StringType(), True),
         StructField('middlename', StringType(), True),
         StructField('lastname', StringType(), True)
         ])),
     StructField('state', StringType(), True),
     StructField('gender', StringType(), True)
     ])
df2 = spark.createDataFrame (data = data, schema = schema)
df2.printSchema ()
df2.show (truncate = False) # shows all columns

# Select struct column
df2.select ("name").show (truncate = False)
# Select struct child columns
df2.select("name.firstname","name.lastname").show (truncate = False)
# Select all child columns
df2.select ("name.*").show (truncate = False)

# Collect () is an action. Returns rows in a Python list. Small set, memory intensive
# select () is a transformation. Returns new DF
dept = [("Finance",10), \
    ("Marketing",20), \
    ("Sales",30), \
    ("IT",40) \
  ]
deptColumns = ["dept_name","dept_id"]
deptDF = spark.createDataFrame (data = dept, schema = deptColumns)
deptDF.printSchema ()
deptDF.show (truncate = False)

dataCollect = deptDF.collect ()

print (dataCollect)

dataCollect2 = deptDF.select ("dept_name").collect ()
print (dataCollect2)

for row in dataCollect:
    print(row['dept_name'] + "," + str(row['dept_id']))
