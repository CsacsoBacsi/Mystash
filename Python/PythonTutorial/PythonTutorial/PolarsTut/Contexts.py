import polars as pl
from datetime import date

bmi_expr = pl.col ("weight") / (pl.col ("height") ** 2) # Lazy representation of a data transformation
print (bmi_expr) # No comptation yet. Just an expression. To compute, we need to use it in a context

df = pl.DataFrame(
    {
        "name": ["Alice Archer", "Ben Brown", "Chloe Cooper", "Daniel Donovan","Csacsi"],
        "birthdate": [date(1997, 1, 10), date(1985, 2, 15), date(1983, 3, 22), date(1981, 4, 30), date(1968, 11, 14)],
        "weight": [57.9, 72.5, 53.6, 83.1, 64],  # (kg)
        "height": [1.56, 1.77, 1.65, 1.75, 1.68],  # (m)
    }
)

print (df)

# Contexts
# *** select ***
result = df.select (
    bmi=bmi_expr,
    avg_bmi=bmi_expr.mean (),
    ideal_max_bmi=25
)
print (result)

# Enum type defines the list of possible values/categories for a column.
types = (
    "Grass Water Fire Normal Ground Electric Psychic Fighting Bug Steel "
    "Flying Dragon Dark Ghost Poison Rock Ice Fairy".split()
)
type_enum = pl.Enum(types) # Define an Enum type with the given categories. The Dataframe column can use this type for better memory efficiency and performance.
pokemon_ = pl.read_csv ("https://gist.githubusercontent.com/ritchie46/cac6b337ea52281aa23c049250a4ff03/raw/89a957ff3919d90e6ef2d34235e6bf22304f3366/pokemon.csv")
pokemon = pokemon_.cast ({"Type 1": type_enum, "Type 2": type_enum}) # String columns "Type 1" and "Type 2" are cast to the defined Enum type.
print (pokemon_.head (5))
print (pokemon)

result = pokemon.select( 
    pl.col ("Name"),
    pl.col ("Type 1"),
    pl.col ("Generation"),
    pl.col ("Speed"),
    pl.col ("Speed").rank ("dense", descending = True).over ("Type 1").alias ("Speed rank")
).filter (pl.col ("Type 1") == "Grass")

with pl.Config(tbl_rows=1000):
    print(result)

# SELECT col is a column expression
df = pokemon.select (["Speed", "Name"])
print (df)
df = pokemon.select (pl.col("Speed") + 10, pl.col("Name")) # Expression
print (df)
df = pokemon.select (pl.col("*"))
print (df)
df = pokemon.select (pl.col("*").exclude (["Type 1", "Type 2"]))
print (df)
df = pokemon.select (pl.col (pl.Int64)) # Select all integer columns
print (df)

# *** with_columns ***
df = pl.DataFrame(
    {
        "name": ["Alice Archer", "Ben Brown", "Chloe Cooper", "Daniel Donovan","Csacsi"],
        "birthdate": [date(1997, 1, 10), date(1985, 2, 15), date(1983, 3, 22), date(1981, 4, 30), date(1968, 11, 14)],
        "weight": [57.9, 72.5, 53.6, 83.1, 64],  # (kg)
        "height": [1.56, 1.77, 1.65, 1.75, 1.68],  # (m)
    }
)
result = df.with_columns ( # Add new columns to the Dataframe. Existing columns are replaced if the new column has the same name.
    bmi=bmi_expr,
    avg_bmi=bmi_expr.mean (),
    ideal_max_bmi=25,
)
print (result)

# *** Filter ***
result = df.filter(
    pl.col("birthdate").is_between(date(1982, 12, 31), date(1996, 1, 1)),
    pl.col("height") > 1.7,
)
print (result)

# *** groupby / agg ***
result = df.group_by (
    (pl.col("birthdate").dt.year() // 10 * 10).alias("decade") # dt is used for datetime operations such as extracting year, month, day, etc.
).agg (pl.col("name"))
print (result)

result = df.group_by (
    (pl.col("birthdate").dt.year() // 10 * 10).alias("decade"),
    (pl.col("height") < 1.7).alias("short?") # Boolean expression as grouping key
).agg (pl.col("name"))
print (result)

result = df.group_by (
    (pl.col("birthdate").dt.year() // 10 * 10).alias("decade"),
    (pl.col("height") < 1.7).alias("short?"),
).agg(
    pl.len(), # Multiple aggregation expressions
    pl.col("name"),
    pl.col("height").max().alias("tallest"),
    pl.col("weight", "height").mean().name.prefix("avg_"),
)
print (result)

expr = (pl.col (pl.Float64) * 1.1).name.suffix ("*1.1") # Expression expansion to scale all Float64 columns by 1.1 and rename them with suffix "*1.1"
result = df.select (pl.col ("name"), expr)
print (result)