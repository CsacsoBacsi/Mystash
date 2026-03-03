from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, ArrayType, MapType
from pyspark.sql.functions import col, struct, when

spark = SparkSession.builder.appName ('Spark SQL').getOrCreate ()

schema = StructType([
 StructField("Id", IntegerType(), True), 
 StructField("Name", StringType(), True),
 StructField("Age", IntegerType(), True)
])
df = spark.createDataFrame ([(1, "Alice", 22), (2, "Bob", 34), (3, "Kate", 18)], schema=schema)
if spark.catalog.tableExists('people'):
    spark.catalog.dropTempView ("people")
df.createTempView ("people")

schema = StructType([
 StructField("Id", IntegerType(), True),
 StructField("OrderItem", StringType(), True),
 StructField("Volume", IntegerType(), True)
])
df2 = spark.createDataFrame([(1, "Cake", 2), (1, "Milk", 3), (3, "Cake", 1), (3, "Choco", 5)], schema=schema)
if spark.catalog.tableExists('orders'):
    spark.catalog.dropTempView ("orders")
df2.createTempView ("orders")
spark.sql ("SELECT * FROM people").show ()
spark.sql ("SELECT * FROM orders").show ()

spark.sql ("SELECT p.id, p.name, o.orderitem, o.volume \
            FROM people p, orders o \
            WHERE p.id = o.id").show ()

# Array of values, initial value (as if it was part of the array), lambda function, finish function (* 10)            
spark.sql ("SELECT reduce(array(1, 2, 3), 1, (acc, x) -> acc + x, acc -> acc * 5)").show ()


