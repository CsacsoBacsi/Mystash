import polars as pl
from datetime import date
import random as rnd

# 1 dimensional dataframe. Name 'ints' is the column name. Data types are inferred as int
s = pl.Series ("ints", [1, 2, 3, 4, 5])
print (s)

s2 = pl.Series ("uints", [1, 2, 3, 4, 5], dtype=pl.UInt64) # Data type explicitly defined

# Dataframes
df = pl.DataFrame (
    {
        "name": ["Alice Archer", "Ben Brown", "Chloe Cooper", "Daniel Donovan"],
        "birthdate": [date(1997, 1, 10), date(1985, 2, 15), date(1983, 3, 22), date(1981, 4, 30)],
        "weight": [57.9, 72.5, 53.6, 83.1],  # (kg)
        "height": [1.56, 1.77, 1.65, 1.75],  # (m)
    }
)

print (df)
print (df.head (2)) # First 2 rows
print (df.glimpse(return_type = 'string')) # Different format output
print (df.tail (2)) # Last 2 rows
rnd.seed (42) # Random number of rows from Dataframe
print (df.sample (2))
print (df.describe()) # Summary statistics
print (df.schema) # Dataframe schema (column names and data types)

# Dataframe with explicit schema
df = pl.DataFrame(
    {
        "name": ["Alice", "Ben", "Chloe", "Daniel"],
        "age": [27, 39, 41, 43],
    },
    schema={"name": pl.String, "age": pl.UInt8},
)

print (df)

# Data types
'''
Boolean	Boolean type that is bit packed efficiently.
Int8, Int16, Int32, Int64, Int128	Varying-precision signed integer types.
UInt8, UInt16, UInt32, UInt64, UInt128	Varying-precision unsigned integer types.
Float32, Float64	Varying-precision signed floating point numbers.
Decimal	Decimal 128-bit type with optional precision and non-negative scale. Use this if you need fine-grained control over the precision of your floats and the operations you make on them. See Python's decimal.Decimal for documentation on what a decimal data type is.
String	Variable length UTF-8 encoded string data, typically Human-readable.
Binary	Stores arbitrary, varying length raw binary data.
Date	Represents a calendar date.
Time	Represents a time of day.
Datetime	Represents a calendar date and time of day.
Duration	Represents a time duration.
Array	Arrays with a known, fixed shape per series; akin to numpy arrays. Learn more about how arrays and lists differ and how to work with both.
List	Homogeneous 1D container with variable length. Learn more about how arrays and lists differ and how to work with both.
Object	Wraps arbitrary Python objects.
Categorical	Efficient encoding of string data where the categories are inferred at runtime. Learn more about how categoricals and enums differ and how to work with both.
Enum	Efficient ordered encoding of a set of predetermined string categories. Learn more about how categoricals and enums differ and how to work with both.
Struct	Composite product type that can store multiple fields. Learn more about the data type Struct in its dedicated documentation section..
Null	Represents null values.
'''