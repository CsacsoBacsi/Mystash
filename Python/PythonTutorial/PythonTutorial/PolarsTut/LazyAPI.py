import polars as pl

# Eager. Executed immediately
df = pl.read_csv("G:\Visual Studio\VS2019Projects\Python\PythonTutorial\PythonTutorial\PolarsTut\CSV\iris.csv")
df_small = df.filter(pl.col("sepal_length") > 5)
df_agg = df_small.group_by("species").agg(pl.col("sepal_width").mean())
print(df_agg)

# Lazy. Builds a query plan, executed upon collect(). When the query is collected, Polars optimizes the execution plan by pushing down filters and projections to minimize data read and processed.
q = (
    pl.scan_csv("G:\Visual Studio\VS2019Projects\Python\PythonTutorial\PythonTutorial\PolarsTut\CSV\iris.csv")
    .filter(pl.col ("sepal_length") > 5)
    .group_by ("species")
    .agg (pl.col("sepal_width").mean ())
)
print (q.explain()) # Show the query plan
df = q.collect ()
print (df)

df = ( # lazy, doesn't do a thing
    pl.scan_csv("G:\Visual Studio\VS2019Projects\Python\PythonTutorial\PythonTutorial\PolarsTut\CSV\my_long_file.csv", has_header = True,
                schema_overrides={"a":pl.Int32, "b":pl.Int32, "c":pl.Int32, "d":pl.Int32, "e":pl.Int32})
    #.with_columns (pl.all ().cast (pl.Int32, strict=False)) 
    .select(
        ["a", "c"]
    )  # select only 2 columns (other columns will not be read)
    #.filter(
    #    pl.col("a") > 10
    #)  # the filter is pushed down the scan, so less data is read into memory
    .head(10)  # constrain number of returned results to 100
).collect ()  # finally, execute the query
print (df)

q.collect (engine="streaming") # Use the streaming execution engine)

