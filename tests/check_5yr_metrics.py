import os, pandas as pd

root_data = "SUSENAS/JAWA BARAT" if os.path.exists("SUSENAS/JAWA BARAT") else "JAWA BARAT"

records = []
for th in range(2019, 2024):
    f = os.path.join(root_data, str(th), "csv", "KOR", f"{th} Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv")
    df = pd.read_csv(f, usecols=['R407', 'R808', 'R802', 'R105'])
    df_5 = df[df['R407'] >= 5]
    
    net_pct = (df_5['R808'] == 1).mean() * 100
    phone_pct = (df_5['R802'] == 1).mean() * 100
    
    # urban vs rural
    urban_net = (df_5[df_5['R105'] == 1]['R808'] == 1).mean() * 100
    rural_net = (df_5[df_5['R105'] == 2]['R808'] == 1).mean() * 100
    
    # generation
    genz_net = (df_5[df_5['R407'] <= 24]['R808'] == 1).mean() * 100
    senior_net = (df_5[df_5['R407'] >= 60]['R808'] == 1).mean() * 100
    
    records.append({
        'year': th,
        'phone_pct': round(phone_pct, 2),
        'net_pct': round(net_pct, 2),
        'urban_net': round(urban_net, 2),
        'rural_net': round(rural_net, 2),
        'gap_urban_rural': round(urban_net - rural_net, 2),
        'genz_net': round(genz_net, 2),
        'senior_net': round(senior_net, 2),
        'gap_gen': round(genz_net - senior_net, 2)
    })

res = pd.DataFrame(records)
print(res.to_string())
