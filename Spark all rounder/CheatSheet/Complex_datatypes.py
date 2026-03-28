from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, ArrayType, MapType
from pyspark.sql.functions import col, struct, when

spark = SparkSession.builder.appName ('Spark SQL').getOrCreate ()

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

spark.sql (query).show ()

# Complex struct with array and nested struct (struct with array, array of struct, struct with array of struct)
query = """
with t1 as (
   select cast ((1, 2, "3-as", array(10, 11, 12), (100, array("500", "600")), array (struct (1, 5, "six"), struct (2, 6, "seven")))
          as struct <field1:int, field2:int, field3:string, arr:array<int>, inner_pocs:struct <field5:int, arr2:array<string>>,
          struct_arr:array<struct<field1:int,field2:int,field3:string>>>) as pocs
)
select pocs.field2, pocs.arr[1], pocs.inner_pocs.arr2[1], pocs.struct_arr[1].field3 from t1

"""
spark.sql (query).show ()

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
spark.sql (query).show ()
