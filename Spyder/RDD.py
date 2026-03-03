# *****************************************
# *** RDD MapReduce and other functions ***
# *****************************************

"""
RDD is just a dataset such as list of names, addresses, prime numbers, just words, etc. 
You can do certain operations on this dataset such as split, count, sum, etc.
These are not tables organized by columns. That is the Dataframe
"""

from pyspark.sql import SparkSession
import pyspark
from pyspark.sql.types import IntegerType, StringType, StructField, StructType

# Create SparkSession. # Running locally with number of partitions (1) in RDD
spark = SparkSession.builder \
  .master ("local[1]") \
  .appName ("Spark RDD") \
  .getOrCreate ()

sc = spark.sparkContext

# Create RDD from parallelize    
data = [1,2,3,4,5,6,7,8,9,10,11,12]
rdd = spark.sparkContext.parallelize (data)

# Create RDD from external Data source
rdd2 = spark.sparkContext.textFile ("C:/users/csacs/downloads/Spark/test.txt")
print ("# RDD from external datasorce (text file)")
print (rdd2.collect ())
# Read entire file into a RDD as single record.
rdd3 = spark.sparkContext.wholeTextFiles ("C:/users/csacs/downloads/Spark/test.txt")
print ("# RDD with a single element which is the whole file")
print (rdd3.collect ())
# Create an empty RDD with no partition    
rdd4 = spark.sparkContext.emptyRDD 
# Create empty RDD with partition
rdd5 = spark.sparkContext.parallelize ([],10) #This creates 10 partitions
# Split the data by space and flatten it
rdd7 = rdd2.flatMap (lambda x: x.split (" "))
print ("# Data is split by space character into individual words")
print (rdd7.collect ())

# *** MapReduce ***
# Apply the map () transformation 
# Add a new element with value 1 to each word
rdd8 = rdd7.map (lambda x: (x, 1))
print ("# Add the value of 1 (occurrence) to each and every word")
print (rdd8.collect ())

# Use reduceByKey(). The key is word+count. Reduce gets the distinct values
rdd9 = rdd8.reduceByKey (lambda a,b: a + b)
print ("# Distinct words with the count of their occurence")
print (rdd9.collect ())
# Using sortByKey(). Revere the order: count (integer), word (string) then sort by count
rdd10 = rdd9.map(lambda x: (x[1], x[0])).sortByKey ()
print ("# Sorted by the number of occurence by each word: ")
print (rdd9.collect ())

# 20 numbers (1 - 20), 4 partitions so 5 values are accummulated in each
rdd11 = sc.parallelize(range (1, 21), 4).map (lambda x: ("single-key", x))
print ("# Values from 1 to 20 under the same key: single-key")
print (rdd11.collect ())
# Accummulate in a. Add b to current accummulated value in a
rdd11 = rdd11.reduceByKey (lambda a, b: a + b)
print ("# Cummulated value from 1 to 20")
print (rdd11.collect ())

# Min and max
data = [9, 15, 8, 23, 2]
rdd12 = sc.parallelize (data)
minval = rdd12.reduce (lambda a, b: min (a, b))
maxval = rdd12.reduce (lambda a, b: max (a, b))
print ("# Minimum value")
print (minval)
print ("# Maximum value")
print (maxval)

# Action - count. Number of records in RDD
print ("# Count : " + str (rdd7.count ()))
# Action - first
firstRec = rdd7.first ()
print ("# First Record first two chars : " + str (firstRec[0]) + "," + firstRec[1])
print ("# First Record : " + str (firstRec))
# Action - max
datMax = rdd7.max ()
print ("Max Record first two chars : " + str (datMax[0]) + "," + datMax[1])
print ("Max Record : " + str (datMax))
# Action - take. First three words
data3 = rdd7.take (3)
for f in data3:
    print("First three words first two charsKey:"+ str (f[0]) + ", Value:" + f[1])
# rdd9.saveAsTextFile ("C:/users/csacs/downloads/Spark/wordCountSorted.txt")

# Cache RDD, persist RDD
cachedRdd = rdd.cache ()
dfPersist = rdd.persist(pyspark.StorageLevel.MEMORY_ONLY)
dfPersist.foreach (print)

# Create broadcast variable
broadcastVar = sc.broadcast([0, 1, 2, 3])
print (broadcastVar.value)
# Create accumulator variable
accum = sc.accumulator (10)
sc.parallelize ([1, 2, 3]).foreach (lambda x: accum.add (x))
print ("Accumulator: " + str (accum))

# Convert DataFrame to RDD
schema = StructType([
  StructField("number", IntegerType())])
df = spark.createDataFrame (rdd, schema)
print (df)
# Convert DataFrame to RDD
rdd = df.rdd

# Create List
numbers = [1,2,1,2,3,4,4,6]
# Creating RDD using parallelize method of SparkContext
rdd = sc.parallelize (numbers)
#Returning distinct elements from RDD
distinct_numbers = rdd.distinct ().collect ()
#Print
print ('Distinct Numbers:', distinct_numbers)