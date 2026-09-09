import os, pandas as pd

root_data = "SUSENAS/JAWA BARAT" if os.path.exists("SUSENAS/JAWA BARAT") else "JAWA BARAT"
f2023 = os.path.join(root_data, "2023", "csv", "KOR", "2023 Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv")

df = pd.read_csv(f2023)
users = df[df['R808'] == 1]
print("Total users:", len(users))
for c in ['R811_A', 'R811_D', 'R811_E', 'R811_G', 'R811_H', 'R811_J']:
    cnt = (users[c] == c[-1]).sum()
    na_cnt = users[c].isna().sum()
    print(f"{c}: match={cnt} ({cnt/len(users)*100:.1f}%), na={na_cnt}")
    print("  sample values:", users[c].unique()[:5])
