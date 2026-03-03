import polars as pl
from datetime import datetime

#
# *** Joins ***
#

props_groups = pl.read_csv("G:\Visual Studio\VS2019Projects\Python\PythonTutorial\PythonTutorial\PolarsTut\CSV\monopoly_props_groups.csv").head(5)
print(props_groups)
props_prices = pl.read_csv("G:\Visual Studio\VS2019Projects\Python\PythonTutorial\PythonTutorial\PolarsTut\CSV\monopoly_props_prices.csv").head(5)
print(props_prices)

result = props_groups.join(props_prices, on="property_name")
print(result)

# Change property_name to lowercase
props_groups2 = props_groups.with_columns (
    pl.col("property_name").str.to_lowercase(),
)
print (props_groups2)
# Change property_name to name
props_prices2 = props_prices.select (
    pl.col("property_name").alias("name"), pl.col("cost")
)
print (props_prices2)

result = props_groups2.join(
    props_prices2,
    left_on="property_name", # Left Dataframe join on
    right_on=pl.col("name").str.to_lowercase() # Right Dataframe join on
)
print (result)

# Inner join only keeps matching rows
result = props_groups.join(props_prices, on="property_name", how="inner")
print (result)

# Left outer join keeps all rows from left dataframe
result = props_groups.join(props_prices, on="property_name", how="left")
print (result)

# Right outer join keeps all rows from right dataframe
result = props_groups.join(props_prices, on="property_name", how="right")
print (result)

# Full outer join keeps all rows from both dataframes
result = props_groups.join(props_prices, on="property_name", how="full")
print (result)

# Semi join keeps all rows from left dataframe that have a match in right dataframe
result = props_groups.join(props_prices, on="property_name", how="semi")
print (result)

# Anti join keeps all rows from left dataframe that do not have a match in right dataframe
result = props_groups.join(props_prices, on="property_name", how="anti")
print (result)

# Non-equi join
players = pl.DataFrame (
    {
        "name": ["Alice", "Bob"],
        "cash": [78, 135],
    }
)
print (players)
result = players.join_where (props_prices, pl.col("cash") > pl.col("cost"))
print (result)

# Asof join
df_trades = pl.DataFrame (
    {
        "time": [
            datetime(2020, 1, 1, 9, 1, 0),
            datetime(2020, 1, 1, 9, 1, 0),
            datetime(2020, 1, 1, 9, 3, 0),
            datetime(2020, 1, 1, 9, 6, 0),
        ],
        "stock": ["A", "B", "B", "C"],
        "trade": [101, 299, 301, 500],
    }
)
print (df_trades)
df_quotes = pl.DataFrame (
    {
        "time": [
            datetime(2020, 1, 1, 9, 0, 0),
            datetime(2020, 1, 1, 9, 2, 0),
            datetime(2020, 1, 1, 9, 4, 0),
            datetime(2020, 1, 1, 9, 6, 0),
        ],
        "stock": ["A", "B", "C", "A"],
        "quote": [100, 300, 501, 102],
    }
)

print (df_quotes)
df_asof_join = df_trades.join_asof(df_quotes, on="time", by="stock")
print (df_asof_join)
df_asof_tolerance_join = df_trades.join_asof (
    df_quotes, on="time", by="stock", tolerance="1m" # Tolerance of 1 minute specified
)
print (df_asof_tolerance_join)

# Cross join
tokens = pl.DataFrame ({"monopoly_token": ["hat", "shoe", "boat"]})

result = players.select (pl.col("name")).join(tokens, how="cross")
print (result)

#
# *** Concatenation ***
#

df_v1 = pl.DataFrame (
    {
        "a": [1],
        "b": [3],
    }
)
df_v2 = pl.DataFrame (
    {
        "a": [2],
        "b": [4],
    }
)
df_vertical_concat = pl.concat ( # Vertical concatenation (stacking)
    [
        df_v1,
        df_v2,
    ],
    how="vertical",
)
print (df_vertical_concat)

df_h1 = pl.DataFrame(
    {
        "l1": [1, 2],
        "l2": [3, 4],
    }
)
df_h2 = pl.DataFrame(
    {
        "r1": [5, 6],
        "r2": [7, 8],
        "r3": [9, 10],
    }
)
df_horizontal_concat = pl.concat ( # Horizontal concatenation (side by side)
    [
        df_h1,
        df_h2,
    ],
    how="horizontal",
)
print (df_horizontal_concat)

df_h1 = pl.DataFrame(
    {
        "l1": [1, 2],
        "l2": [3, 4],
    }
)
df_h2 = pl.DataFrame(
    {
        "r1": [5, 6, 7],
        "r2": [8, 9, 10],
    }
)
df_horizontal_concat = pl.concat ( # Horizontal concatenation with different row counts
    [
        df_h1,
        df_h2,
    ],
    how="horizontal",
)
print (df_horizontal_concat)

df_d1 = pl.DataFrame(
    {
        "a": [1],
        "b": [3],
    }
)
df_d2 = pl.DataFrame(
    {
        "a": [2],
        "d": [4],
    }
)

df_diagonal_concat = pl.concat ( # Diagonal concatenation (longer of two dataframes, filling missing values with nulls) and wider of two dataframes, filling missing columns with nulls
    [
        df_d1,
        df_d2,
    ],
    how="diagonal", rechunk = True
)
print (df_diagonal_concat)

# *** Rechunking ***
'''
Before a concatenation we have two dataframes df1 and df2. Each column in df1 and df2 is in one or more chunks in memory. By default, 
during concatenation the chunks in each column are not made contiguous. This makes the concat operation faster and consume less memory 
but it may slow down future operations that would benefit from having the data be in contiguous memory. The process of copying the fragmented chunks
into a single new chunk is known as rechunking. Rechunking is an expensive operation. Prior to version 0.20.26, the default was to perform a rechunk
but in new versions, the default is not to. If you do want Polars to rechunk the concatenated DataFrame you specify rechunk = True when doing the concatenation.
'''
