import polars as pl

df = pl.DataFrame(
    {
        "a": [12, 25, 3, None, 1],
        "b": [6.0, 5.0, 4.0, 9.1, 1.1],
        "c": ["a", "c", "b", "a", "a"],
    }
)
print (df)
df = df.sort(["c", "a"], descending=[True, False], nulls_last=True) # Sorts the whole dataframe by column 'c' descending, then by column 'a' ascending, placing nulls last
print (df)

df = pl.DataFrame(
    {
        "a": [12, 25, 3, None, 1],
        "b": [6.0, 5.0, 4.0, 9.1, 1.1],
        "c": ["a", "c", "b", "a", "a"],
    }
)
df = df.select (pl.col ("a"), pl.col ("b"), pl.col("c").sort_by(["a"], descending = True, nulls_last=True)) # Sorts only column 'c' by values in column 'a'
print (df)