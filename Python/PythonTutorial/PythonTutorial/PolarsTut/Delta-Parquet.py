import polars as pl
from datetime import datetime

# Write to Parquet with partitioning
df = pl.DataFrame({"a": [1, 2, 3], "watermark": [4, 5, 6]})
path = "G:\Visual Studio\VS2019Projects\Python\PythonTutorial\PythonTutorial\PolarsTut\Parquet\parquet_example.parquet"
df.write_parquet(
    path,
    use_pyarrow=True,
    #pyarrow_options={"partition_cols": ["watermark"]},
)

# Read from Parquet with partitioning
path = "G:\Visual Studio\VS2019Projects\Python\PythonTutorial\PythonTutorial\PolarsTut\Parquet\parquet_example.parquet"
df_read = pl.read_parquet(
    path
)
print (df_read)

schema = pl.read_parquet_schema ("G:\Visual Studio\VS2019Projects\Python\PythonTutorial\PythonTutorial\PolarsTut\Parquet\parquet_example.parquet")
print (schema)

df_read.drop_in_place ("a")
print (df_read)
path = "G:\Visual Studio\VS2019Projects\Python\PythonTutorial\PythonTutorial\PolarsTut\Parquet\parquet_example2.parquet"
df_read.write_parquet (
    path,
    use_pyarrow=True,
    #pyarrow_options={"partition_cols": ["watermark"]},
)


# Write Delta Lake format (using Parquet as underlying format)
df = pl.DataFrame(
    {
        "foo": [1, 2, 3, 4, 5, 6],
        "bar": [6, 7, 8, 9, 10, 11],
        "ham": ["a", "b", "c", "d", "e", "f"],
    }
)
path = "D:\Data\DeltaLake\delta_example"
#path = "G:\Visual Studio\VS2019Projects\Python\PythonTutorial\PythonTutorial\PolarsTut\Delta\delta_example"
df.write_delta(
    path,
    mode="overwrite",
    delta_write_options={"schema_mode": "overwrite"},
)

df = pl.read_delta (path)
print (df)