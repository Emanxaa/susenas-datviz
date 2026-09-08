import os
import sqlite3
from pathlib import Path
from literature.parser import run_parser

def test_add_new_paper_automatically_updates_knowledge_base():
    paper_path = Path("literature/papers/paper_test_scenario4.md")
    
    # 1. Create a brand new paper file
    test_paper_content = """---
paper_id: TEST_AUTHOR_2024_NEW
title: "Pengaruh Ketahanan Pangan Terhadap Prestasi Belajar Anak Sekolah di Jawa Barat"
year: 2024
authors: "Kusuma, B., & Lestari, P."
source: "Jurnal Pendidikan dan Kebijakan Publik, Vol. 12(1)"
---

# Abstrak
Studi eksperimental korelasi skor FIES dengan capaian kognitif.

## Concepts
- food_insecurity
- education_head

## Findings
- finding: "Rumah tangga rawan pangan memiliki korelasi negatif yang signifikan dengan lama sekolah anak."
  concept: food_insecurity
  evidence_strength: "High"
  variables: ["R1701", "R612", "R614"]
"""
    try:
        paper_path.write_text(test_paper_content.strip() + "\n", encoding="utf-8")
        
        # 2. Run parser without modifying any code
        run_parser()
        
        # 3. Verify paper was automatically added to database/evidence.db
        conn = sqlite3.connect("database/evidence.db")
        cur = conn.cursor()
        row = cur.execute("SELECT title, year, authors FROM papers WHERE paper_id = 'TEST_AUTHOR_2024_NEW'").fetchone()
        assert row is not None, "New paper must be automatically inserted into papers table"
        assert row[0] == "Pengaruh Ketahanan Pangan Terhadap Prestasi Belajar Anak Sekolah di Jawa Barat"
        assert row[1] == 2024
        
        # 4. Verify findings and variables were inserted
        f_rows = cur.execute("SELECT finding FROM findings WHERE paper_id = 'TEST_AUTHOR_2024_NEW'").fetchall()
        assert len(f_rows) == 1
        
        v_rows = cur.execute("SELECT v.variable_concept FROM finding_variables v JOIN findings f ON v.finding_id = f.finding_id WHERE f.paper_id = 'TEST_AUTHOR_2024_NEW'").fetchall()
        vars_found = {vr[0] for vr in v_rows}
        assert {"R1701", "R612", "R614"}.issubset(vars_found)
        
        conn.close()
        
    finally:
        # Cleanup test paper and re-run parser to restore original state
        paper_path.unlink(missing_ok=True)
        conn = sqlite3.connect("database/evidence.db")
        conn.execute("DELETE FROM finding_variables WHERE finding_id LIKE 'TEST_AUTHOR_2024_NEW%'")
        conn.execute("DELETE FROM findings WHERE paper_id = 'TEST_AUTHOR_2024_NEW'")
        conn.execute("DELETE FROM papers WHERE paper_id = 'TEST_AUTHOR_2024_NEW'")
        conn.commit()
        conn.close()
        run_parser()
