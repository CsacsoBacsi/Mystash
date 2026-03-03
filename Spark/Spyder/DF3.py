# **********************************
# *** DataFrame column functions ***
# **********************************

from pyspark.sql.functions import lit
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, ArrayType, MapType
from pyspark.sql.functions import col, struct, when
from pyspark.sql.functions import expr
import sys

spark = SparkSession.builder.appName ('Spark DF').getOrCreate ()

data = [("James","Bond","100",None),
        ("Ann","Varsa","200",'F'),
        ("Tom Cruise","XXX","400",''),
        ("Tom Brand",None,"400",'M')] 
columns = ["fname","lname","id","gender"]
df = spark.createDataFrame (data, columns)

# alias
df.select (df.fname.alias ("first_name"), df.lname.alias ("last_name")).show ()

# Another example. expr returns a Column parsing the expression into it
df.select (expr (" fname ||','|| lname").alias ("fullName")).show ()

# asc, desc to sort ascending and descending order repsectively.
df.sort (df.fname.asc  ()).show ()
df.sort (df.fname.desc ()).show ()
# Cast data type
df2 = df.select (df.fname,df.id.cast ("int"))
df2.show ()
df2.printSchema ()
# Filter data and between operator. Filter is like a where-clause only on DF
df.filter (df.id.between (100, 300)).show ()
# Contains
df.filter (df.fname.contains("Cruise")).show ()
df.filter (df.fname.contains("ran")).show ()
# startswith, endswith
df.filter (df.fname.startswith ("T")).show ()
df.filter (df.fname.endswith ("Cruise")).show ()
# isNull & isNotNull
df.filter (df.lname.isNull ()).show ()
df.filter (df.lname.isNotNull ()).show ()
# like, rlike
df.select (df.fname, df.lname, df.id).filter (df.fname.like("%om%")).show () 
# substr
df.select (df.fname.substr (1, 2).alias ("substr")).show ()
# when (case statement)
df.select (df.fname,df.lname,when(df.gender=="M","Male") \
              .when(df.gender=="F","Female") \
              .when(df.gender==None ,"") \
              .otherwise(df.gender).alias("new_gender")).show ()
# isin
li = ["100","200"]
df.select (df.fname,df.lname,df.id).filter (df.id.isin (li)).show ()

#Create DataFrame with struct, array & map
from pyspark.sql.types import StructType,StructField,StringType,ArrayType,MapType
data=[(("James","Bond"),["Java","C#"],{'hair':'black','eye':'brown'}),
      (("Ann","Varsa"),[".NET","Python"],{'hair':'brown','eye':'black'}),
      (("Tom Cruise",""),["Python","Scala"],{'hair':'red','eye':'grey'}),
      (("Tom Brand",None),["Perl","Ruby"],{'hair':'black','eye':'blue'})]

schema = StructType([
        StructField('name', StructType([
            StructField('fname', StringType (), True),
            StructField('lname', StringType (), True)])),
        StructField('languages', ArrayType (StringType()),True),
        StructField('properties', MapType (StringType(),StringType()),True)
     ])
df = spark.createDataFrame (data,schema)
df.printSchema ()

# getField from MapType
df.select (df.properties.getField ("hair")).show ()
# getField from Struct
df.select (df.name.getField ("fname")).show ()

# getItem() used with ArrayType. Zero-based index
df.select (df.languages.getItem (1)).show ()
# getItem() used with MapType (same as getField ("hair"))
df.select (df.properties.getItem ("hair")).show ()


