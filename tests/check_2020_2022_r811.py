import os, pandas as pd

root_data = "SUSENAS/JAWA BARAT" if os.path.exists("SUSENAS/JAWA BARAT") else "JAWA BARAT"

for yr in [2020, 2022]:
    f = os.path.join(root_data, str(yr), "csv", "KOR", f"{yr} Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv")
    df = pd.read_csv(f, nrows=5000)
    print(f"\n--- YEAR {yr} ---")
    users = df[df['R808'] == 1]
    for c in ['R811_A', 'R811_D', 'R811_E', 'R811_G', 'R811_H', 'R811_J']:
        if c in df.columns:
            print(f"  {c}:", users[c].value_counts(dropna=False).to_dict())
        else:
            print(f"  {c}: NOT FOUND")
