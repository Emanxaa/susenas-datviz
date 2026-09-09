import pandas as pd

file_2023 = "SUSENAS/JAWA BARAT/2023/Metadata dan Kuisoner/KOR 2023 Layout_data_Susenas.xlsx"
excel = pd.ExcelFile(file_2023)

df_rt = pd.read_excel(excel, sheet_name="Kor RT")
print("\nCols in Kor RT:", df_rt.columns.tolist())
print(df_rt.head(2))

# Find the exact column names in df_rt
var_col = [c for c in df_rt.columns if 'var' in str(c).lower()][0]
label_col = [c for c in df_rt.columns if 'label' in str(c).lower() or 'desc' in str(c).lower()][0]

vars_target = ["R101", "R102", "R105", "R301", "FWT", 
               "R1701", "R1702", "R1703", "R1704", "R1705", "R1706", "R1707", "R1708"]

matched = df_rt[df_rt[var_col].isin(vars_target)]
print("\n=== MATCHED VARIABLES IN KOR RT 2023 ===")
for idx, row in matched.iterrows():
    print(f"Var: {row[var_col]:<8} | Label: {row[label_col]}")

df_val = pd.read_excel(excel, sheet_name="value labels Kor RT")
print("\n=== VALUE LABELS SAMPLE ===")
val_var_col = [c for c in df_val.columns if 'var' in str(c).lower()][0]
print(df_val[df_val[val_var_col].isin(['R1701', 'R105'])].head(10).to_string())
