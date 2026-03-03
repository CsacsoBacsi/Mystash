import polars as pl

# Rank column "a" values (within groups defined by column "a") based on column "b" values using ordinal ranking
# Same as ranking order values by same customer (over customer or partition by customer). pl.col("order_value").rank("ordinal").over("customer_id")
# SQL: SELECT customer, order_value, RANK (order_value) OVER (PARTITION BY customer_id) AS rank_order_values_over_customer_id FROM df ;
df = pl.DataFrame ({"a": [1, 1, 2, 2, 2], "b": [6, 7, 5, 14, 11]})
df = df.with_columns (pl.col("b").rank("ordinal").over ("a").alias ("rank_b_over_a"))
df = df.with_columns (pl.col("a").rank("ordinal").over ("a").alias ("rank_a_over_a"))
print (df)
df = pl.DataFrame ({"customer_id": [1, 1, 2, 2, 2, 3, 3], "order_value": [6, 7, 5, 14, 11, 8, 5]})
# with_columns to add new columns to the Dataframe. Existing columns are replaced if the new column has the same name.
df = df.with_columns (pl.col("order_value").rank("ordinal").over ("customer_id").alias ("rank_order_values_over_customer_id"))
print (df)

# Filter is applied before window functions
df = pl.DataFrame ({"customer_id": [1, 1, 2, 2, 2, 2, 2], "order_value": [6, 7, 5, 14, 11, 8, 17], "filter": [0, 0, 1, 1, 1, 0, 0]})
print (df)
df = df.select (
    pl.col ("customer_id"),
    pl.col ("order_value"),
    pl.col ("filter"),
    pl.col ("order_value").rank ("ordinal", descending = True).over ("customer_id").alias ("Order value rank")
).filter (pl.col ("filter") == 1) # Post filter
print (df)

df = pl.DataFrame ({"customer_id": [1, 1, 2, 2, 2, 2, 2], "order_value": [6, 7, 5, 14, 11, 8, 17], "filter": [0, 0, 1, 1, 1, 0, 0]})
df = df.filter (pl.col ("filter") == 1 # Pre filter
).select (
    pl.col ("customer_id"),
    pl.col ("order_value"),
    pl.col ("filter"),
    pl.col ("order_value").rank ("ordinal", descending = True).over ("customer_id").alias ("Order value rank")
)
print (df)