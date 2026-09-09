import os, glob, pandas as pd

root_data = "SUSENAS/JAWA BARAT" if os.path.exists("SUSENAS/JAWA BARAT") else "JAWA BARAT"

for th in range(2019, 2024):
    p1 = os.path.join(root_data, str(th), "csv", "KOR", f"{th} Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv")
    p2 = os.path.join(root_data, str(th), "csv", "KOR", f"{th} Maret JABAR - SUSENAS KOR INDIVIDU PART2.csv")
    
    hdr1 = pd.read_csv(p1, nrows=1).columns.tolist()
    hdr2 = pd.read_csv(p2, nrows=1).columns.tolist()
    
    # Check where R801, R802, R808 or R1001, etc. exist
    found_in_1 = [c for c in hdr1 if c.startswith('R8') or c.startswith('R10') or 'INTERNET' in c.upper() or 'HP' in c.upper()]
    found_in_2 = [c for c in hdr2 if c.startswith('R8') or c.startswith('R10') or 'INTERNET' in c.upper() or 'HP' in c.upper()]
    
    print(f"\n--- TAHUN {th} ---")
    if any(c in hdr1 for c in ['R801', 'R802', 'R808', 'R1001', 'R1004']):
        print("Found in PART1:", [c for c in ['R801', 'R802', 'R808', 'R1001', 'R1004'] if c in hdr1])
    if any(c in hdr2 for c in ['R801', 'R802', 'R808', 'R1001', 'R1004']):
        print("Found in PART2:", [c for c in ['R801', 'R802', 'R808', 'R1001', 'R1004'] if c in hdr2])
