# ***********************************
# *** DataFrame column operations ***
# ***********************************

from pyspark.sql.functions import lit
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, ArrayType, MapType
from pyspark.sql.functions import col, struct, when
from pyspark.sql import Row

spark = SparkSession.builder.appName ('Spark DF').getOrCreate ()

# Creates a Column of literal value
colObj = lit ("mycol")

data=[("James",23),("Ann",40)]
df=spark.createDataFrame (data).toDF ("name.fname","age")
df.printSchema()

# Using DataFrame object (df) select a DataFrame column and create new DF
df.select (df.age).show ()
df.select (df["age"]).show ()
# Accessing column name with dot (with backticks)
df.select (df["`name.fname`"]).show ()

# Using SQL col() function. Returns a Column based on the given column name
df.select (col ("age")).show ()
# Accessing column name with dot (with backticks)
df.select (col ("`name.fname`")).show ()

# Create DataFrame with struct using Row class
data=[Row (name = "James",prop = Row (hair = "black",eye = "blue")),
      Row (name = "Ann",prop = Row (hair = "grey", eye = "black"))]
df = spark.createDataFrame (data)
df.printSchema ()
#root
# |-- name: string (nullable = true)
# |-- prop: struct (nullable = true)
# |    |-- hair: string (nullable = true)
# |    |-- eye: string (nullable = true)

# Access struct column. Projects a set of expressions and returns a new DataFrame
df.select (df.prop.hair).show ()
df.select (df["prop.hair"]).show ()
df.select (col ("prop.hair")).show ()

#Access all columns from struct
df.select (col ("prop.*")).show ()

# Colum arithmetic
data = [(100,2,1),(200,3,4),(300,4,4)]
# Returns a new DataFrame that with new specified column names
df = spark.createDataFrame (data).toDF ("col1","col2","col3")

# Arithmetic operations
df.select (df.col1 + df.col2).show ()
df.select (df.col1 - df.col2).show () 
df.select (df.col1 * df.col2).show ()
df.select (df.col1 / df.col2).show ()
df.select (df.col1 % df.col2).show ()

df.select (df.col2 > df.col3).show ()
df.select (df.col2 < df.col3).show ()
df.select (df.col2 == df.col3).show ()