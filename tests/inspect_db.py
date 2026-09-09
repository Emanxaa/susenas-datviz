import sqlite3

con = sqlite3.connect("database/metadata.db")
cur = con.cursor()
tables = cur.execute("SELECT name, sql FROM sqlite_master WHERE type='table'").fetchall()
for t, sql in tables:
    print(f"--- TABLE: {t} ---")
    print(sql)

print("\nSample from each table:")
for t, _ in tables:
    print(f"\n--- SAMPLE: {t} ---")
    try:
        rows = cur.execute(f"SELECT * FROM {t} LIMIT 3").fetchall()
        col_names = [d[0] for d in cur.description]
        print("Cols:", col_names)
        for r in rows:
            print(r)
    except Exception as e:
        print("Error:", e)
