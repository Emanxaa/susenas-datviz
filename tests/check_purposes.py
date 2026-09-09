import os, pandas as pd

root_data = "SUSENAS/JAWA BARAT" if os.path.exists("SUSENAS/JAWA BARAT") else "JAWA BARAT"

for th in range(2019, 2024):
    p1 = os.path.join(root_data, str(th), "csv", "KOR", f"{th} Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv")
    hdr = pd.read_csv(p1, nrows=1).columns.tolist()
    r811_cols = [c for c in hdr if c.startswith('R811') or c.startswith('R1005')]
    print(f"Tahun {th} internet purpose cols in PART1:", r811_cols[:6])
