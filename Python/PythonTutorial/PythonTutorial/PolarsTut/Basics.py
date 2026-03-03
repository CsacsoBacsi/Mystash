import polars as pl
import numpy as np

np.random.seed(42)  # For reproducibility.

df = pl.DataFrame(
    {
        "nrs": [1, 2, 3, None, 5],
        "names": ["foo", "ham", "spam", "egg", "spam"],
        "random": np.random.rand(5),
        "groups": ["A", "A", "B", "A", "B"],
    }
)
print (df)

result = df.select(
    (pl.col("nrs") + 5).alias("nrs + 5"),
    (pl.col("nrs") - 5).alias("nrs - 5"),
    (pl.col("nrs") * pl.col("random")).alias("nrs * random"),
    (pl.col("nrs") / pl.col("random")).alias("nrs / random"),
    (pl.col("nrs") ** 2).alias("nrs ** 2"),
    (pl.col("nrs") % 3).alias("nrs % 3"),
)

print (result)

result_named_operators = df.select(
    (pl.col("nrs").add(5)).alias("nrs + 5"),
    (pl.col("nrs").sub(5)).alias("nrs - 5"),
    (pl.col("nrs").mul(pl.col("random"))).alias("nrs * random"),
    (pl.col("nrs").truediv(pl.col("random"))).alias("nrs / random"),
    (pl.col("nrs").pow(2)).alias("nrs ** 2"),
    (pl.col("nrs").mod(3)).alias("nrs % 3"),
)

print (result.equals(result_named_operators))

result = df.select(
    (pl.col("nrs") > 1).alias("nrs > 1"),  # .gt
    (pl.col("nrs") >= 3).alias("nrs >= 3"),  # ge
    (pl.col("random") < 0.2).alias("random < .2"),  # .lt
    (pl.col("random") <= 0.5).alias("random <= .5"),  # .le
    (pl.col("nrs") != 1).alias("nrs != 1"),  # .ne
    (pl.col("nrs").eq (1)).alias("nrs == 1"),  # .eq
)
print (result)

# Boolean operators & | ~
result = df.select(
    ((~pl.col("nrs").is_null()) & (pl.col("groups") == "A")).alias(
        "number not null and group A"
    ),
    ((pl.col("random") < 0.5) | (pl.col("groups") == "B")).alias(
        "random < 0.5 or group B"
    ),
)

print(result)

# Corresponding named functions `and_`, `or_`, and `not_`.
result2 = df.select(
    (pl.col("nrs").is_null().not_().and_(pl.col("groups") == "A")).alias(
        "number not null and group A"
    ),
    ((pl.col("random") < 0.5).or_(pl.col("groups") == "B")).alias(
        "random < 0.5 or group B"
    ),
)
print (result.equals(result2))

# Bitwise operators & | ^
result = df.select(
    pl.col("nrs"),
    (pl.col("nrs") & 6).alias("nrs & 6"),
    (pl.col("nrs") | 6).alias("nrs | 6"),
    (~pl.col("nrs")).alias("not nrs"),
    (pl.col("nrs") ^ 6).alias("nrs ^ 6"),
)

print (result)

long_df = pl.DataFrame({"numbers": np.random.randint(0, 100000, 1000)}) # Generate 1000 random integers between 0 and 100000
print (long_df)

result = long_df.select(
    pl.col("numbers").n_unique().alias("n_unique"),
    pl.col("numbers").approx_n_unique().alias("approx_n_unique"),
)

print(result)