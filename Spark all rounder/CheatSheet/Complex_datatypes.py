from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, ArrayType, MapType
from pyspark.sql.functions import col, struct, when

spark = SparkSession.builder.appName ('Spark SQL').getOrCreate ()
print ("")
print ("Complex datatypes in Spark SQL")
print ("")

# Arrays are only equal if the elements are in the same order. So, sort_array is used here to sort the arrays before comparing them. 
query = """
with t1 as (
    select 1 as id, sort_array (array(1,5,2,3,4)) as arr
), t2 as (
    select 1 as id, sort_array (array(1,2,3,4,5)) as arr
)
select case when t1.arr = t2.arr then 'equal' else 'not equal' end as result
from t1
join t2 on t1.id = t2.id


"""
print ("Array equality comparison:")
spark.sql (query).show (truncate = False)

# Complex struct with array and nested struct (struct with array, array of struct, struct with array of struct)
query = """
with t1 as (
   select cast ((1, 2, "3-as", array(10, 11, 12), (100, array("500", "600")), array (struct (1, 5, "six"), struct (2, 6, "seven")))
          as struct <field1:int, field2:int, field3:string, arr:array<int>, inner_pocs:struct <field5:int, arr2:array<string>>,
          struct_arr:array<struct<field1:int,field2:int,field3:string>>>) as pocs
)
select pocs.field2, pocs.arr[1], pocs.inner_pocs.arr2[1], pocs.struct_arr[1].field3 from t1

"""
print ("Struct with array, array of struct, struct with array of struct:")
spark.sql (query).show (truncate = False)

# Structs with arrays are equal if the fields are equal, and the arrays are equal (same elements in the same order). So, sort_array is used
# Structs will not be equal if the fields are in different order despite having the same field names and values
query = """
with t1 as (
    SELECT 1 as id, cast (struct (1, 2, "three", sort_array (array (1, 2))) as struct <field1:int, field2:int, field3:string, field4:array<int>>) as stru
), t2 as (
    SELECT 1 as id, cast (struct (2, 1, "three", sort_array (array (2, 1))) as struct <field2:int, field1:int, field3:string, field4:array<int>>) as stru
)
select case when t1.stru = t2.stru then 'equal' else 'not equal' end as result
from t1
join t2 on t1.id = t2.id
"""
print ("Struct equality comparison:")
spark.sql (query).show (truncate = False)

# Map
query = """
with t1 as (
   select cast (map (1, "one", 2, "two", 3, "three") 
          as map<int, string>) as my_map,
          cast (map ("one", struct (1,2,"a"), "two", struct (3,4,"b"), "three", struct (5, 6,"c")) 
          as map<string, struct<field1:int, field2:int, field3:string>>) as my_map2
)
select my_map[2], my_map2["two"].field3
from t1
"""
print ("Map (key-value pair) access:")
spark.sql (query).show (truncate = False)

# This below does not work as maps do not support equality comparison. 
# So, we can use the map_entries function to convert the maps into arrays of key-value pairs and then compare those arrays.
query = """
with t1 as (
   select 1 as id, cast (map (1, "one", 2, "two", 3, "three") as map<int, string>) as my_map
), t2 as (
   select 1 as id, cast (map (1, "one", 2, "two", 3, "three") as map<int, string>) as my_map
)
select case when map_entries (t1.my_map) = map_entries (t2.my_map) then 'equal' else 'not equal' end as result
from t1
join t2 on t1.id = t2.id
"""
print ("Map equality comparison:")
spark.sql (query).show (truncate = False)