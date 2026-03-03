import logging
from pyspark import SparkContext

logFile = "file:///usr/hdp/3.0.1.0-187/spark2/README.md"
sc = SparkContext("local", "first app")

# Disables further INFO logging 
log4j = sc._jvm.org.apache.log4j
log4j.LogManager.getRootLogger().setLevel(log4j.Level.ERROR)

logData = sc.textFile(logFile).cache()
numAs = logData.filter(lambda s: 'a' in s).count()
numBs = logData.filter(lambda s: 'b' in s).count()
print "Lines with a: %i, lines with b: %i" % (numAs, numBs)
words = sc.parallelize (
   ["scala", 
   "java", 
   "hadoop", 
   "spark", 
   "akka",
   "spark vs hadoop", 
   "pyspark",
   "pyspark and spark"]
)
counts = words.count()
print "Number of elements in RDD -> %i" % (counts)

# Prints all elements (with collect ())
coll = words.collect()
print "Elements in RDD -> %s" % (coll)

# Applies a function to all elements
def f(x): print (x)
fore = words.foreach(f)

# Applies filter to all elements (applies a function)
words_filter = words.filter (lambda x: 'spark' in x)
filtered = words_filter.collect ()
print "Filtered RDD -> %s" % (filtered)

# Joins two sets (RDDs) on common key (spark, hadoop)
x = sc.parallelize([("spark", 1), ("hadoop", 4)])
y = sc.parallelize([("spark", 2), ("hadoop", 5)])
joined = x.join(y)
final = joined.collect()
print "Join RDD -> %s" % (final)

# Broadcast variable - copied to all nodes in the value attribute
words_new = sc.broadcast(["scala", "java", "hadoop", "spark", "akka"]) 
data = words_new.value 
print "Stored data -> %s" % (data) 
elem = words_new.value[2] 
print "Printing a particular element in RDD -> %s" % (elem)

# Accummulator - used by multiple workers
num = sc.accumulator(10) 
def f(x): 
   global num 
   num+=x 
rdd = sc.parallelize([20,30,40,50]) 
rdd.foreach(f) 
final = num.value 
print "Accumulated value is -> %i" % (final)


