import os, pandas as pd

root_data = "SUSENAS/JAWA BARAT" if os.path.exists("SUSENAS/JAWA BARAT") else "JAWA BARAT"
f2023 = os.path.join(root_data, "2023", "csv", "KOR", "2023 Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv")

cols = ["R808", "R811_A", "R811_D", "R811_E", "R811_G", "R811_H", "R811_J"]
df = pd.read_csv(f2023, usecols=cols)
for c in cols:
    print(f"Col {c} unique values:", df[c].value_counts(dropna=False).to_dict())
