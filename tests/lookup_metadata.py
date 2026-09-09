import sqlite3
import pandas as pd

con = sqlite3.connect("database/metadata.db")
vars_to_check = ["R101", "R102", "R105", "R301", "FWT", 
                 "R1701", "R1702", "R1703", "R1704", "R1705", "R1706", "R1707", "R1708"]

query = f"""
SELECT variable, label, module, year, data_type, metadata_source
FROM variable_registry 
WHERE variable IN ({','.join(repr(v) for v in vars_to_check)})
ORDER BY variable, year
"""
df = pd.read_sql_query(query, con)
print("=== VARIABLE REGISTRY ===")
print(df.drop_duplicates(subset=['variable', 'label']).to_string())

query_val = f"""
SELECT variable, value, label
FROM value_labels
WHERE variable IN ({','.join(repr(v) for v in vars_to_check)})
ORDER BY variable, CAST(value AS INTEGER)
"""
df_val = pd.read_sql_query(query_val, con)
print("\n=== VALUE LABELS ===")
print(df_val.to_string())
