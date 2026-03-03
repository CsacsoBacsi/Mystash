from pyspark import SparkContext
from pyspark.sql import SparkSession
 
sc = SparkContext.getOrCreate()
sc.setLogLevel ("ERROR") 

# RDD 
print ("\nUsing RDD...")
print sc.textFile( "/examples/src/main/resources/users.csv" ) \
    .map(lambda x: (x.split('|')[2],1) ) \
    .reduceByKey( lambda x,y:x+y ) \
    .collect()

result = sc.textFile( "/examples/src/main/resources/users.csv" ) \
    .map(lambda x: (x.split('|')[3],1) ) \
    .filter( lambda x: x[0] != 'other' ) \
    .reduceByKey( lambda x,y:x+y ) \
    .sortBy( lambda x: -x[1] ).collect()

for line in result:
    print line    

# DataFrame
print ("\nUsing DataFrame...")
spark = SparkSession(sc)
spark.read.load( "/examples/src/main/resources/users.csv", format="csv", sep="|" ) \
      .toDF( "id","age","gender","occupation","zip" ) \
      .groupby( "gender" ) \
      .count().show()

spark.read.load( "/examples/src/main/resources/users.csv", format="csv", sep="|" ) \
   .toDF( "id","age","gender","occupation","zip" ) \
   .where( "occupation != 'other'" ) \
   .groupby( "occupation" ) \
   .count().sort("count", ascending=0) \
   .show()


print ("\nUsing SQL...")
spark.read.load( "/examples/src/main/resources/users.csv", format="csv", sep="|" ) \
      .toDF( "id","age","gender","occupation","zip" ) \
      .createOrReplaceTempView( "users" )

spark.sql( "select gender, count(*) from users group by gender" ).show()

df = spark.read.load( "/examples/src/main/resources/users.csv", format="csv", sep="|" ) \
    .toDF( "id","age","gender","occupation","zip" )

df.write.saveAsTable( "users", mode="overwrite" )
df.write.save("users_json", format="json", mode="overwrite")    
df.write.save("users_parquet", format="parquet", mode="overwrite")    
df.write.save("users_csv", format="csv", mode="overwrite")    

spark.sql("SELECT gender, count(*) FROM \
        json.`users_json` GROUP BY gender").show()

spark.sql ("select id, age, gender, occupation, zip, row_number () over (partition by occupation order by age) as rn from users order by occupation, age").show ()
spark.sql ("with src (select id, age, gender, occupation, zip, row_number () over (partition by occupation order by age) as rn from users) select * from src where rn = 1 order by occupation, age").show (50)

sc.stop()

