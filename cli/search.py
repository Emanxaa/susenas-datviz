#!/usr/bin/env python3
"""
Interactive Search CLI for SUSENAS Research Discovery Engine.

Search across:
  1. Semantic concepts & keywords
  2. Survey variables & multi-year compatibility
  3. Literature papers & scientific findings
  4. Survey dataset catalog

Usage:
  python cli/search.py "FIES"
  python cli/search.py "balita"
  python cli/search.py "bansos"
"""

import sys
import sqlite3
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
METADATA_DB = ROOT_DIR / "database/metadata.db"
EVIDENCE_DB = ROOT_DIR / "database/evidence.db"

def search_all(query: str):
    q_lower = query.lower()
    q_wild = f"%{query}%"

    print(f"\nSearch Results for: \"{query}\"")
    print("=" * 65)

    # 1. Search variable_compatibility
    if METADATA_DB.exists():
        conn = sqlite3.connect(METADATA_DB)
        cur = conn.cursor()

        cur.execute("""
            SELECT variable_concept, domain, var_2019, var_2020, var_2021, var_2022, var_2023, module
            FROM variable_compatibility
            WHERE variable_concept LIKE ? OR var_2019 LIKE ? OR var_2023 LIKE ? OR domain LIKE ?
        """, (q_wild, q_wild, q_wild, q_wild))
        compat_rows = cur.fetchall()

        if compat_rows:
            print(f"\n[Variables & Compatibility Matrix] ({len(compat_rows)} found)")
            print("-" * 65)
            for r in compat_rows[:5]:
                concept, domain, v19, v20, v21, v22, v23, mod = r
                print(f"  ? Concept: {concept} ({domain})")
                print(f"    Years  : 2019:{v19} | 2020:{v20} | 2021:{v21} | 2022:{v22} | 2023:{v23}")
                print(f"    Module : {mod}")

        # Search survey_catalog
        cur.execute("""
            SELECT year, module, file_name, file_format
            FROM survey_catalog
            WHERE file_name LIKE ? OR module LIKE ?
            ORDER BY year DESC
        """, (q_wild, q_wild))
        cat_rows = cur.fetchall()
        if cat_rows:
            print(f"\n[Survey Catalog Files] ({len(cat_rows)} found)")
            print("-" * 65)
            for cr in cat_rows[:5]:
                print(f"  ? [{cr[0]}] {cr[1].upper()}: {cr[2]}")

        conn.close()

    # 2. Search evidence.db
    if EVIDENCE_DB.exists():
        conn = sqlite3.connect(EVIDENCE_DB)
        cur = conn.cursor()

        cur.execute("""
            SELECT p.title, p.authors, p.year, f.finding, f.evidence_strength
            FROM findings f
            JOIN papers p ON f.paper_id = p.paper_id
            WHERE f.finding LIKE ? OR p.title LIKE ?
        """, (q_wild, q_wild))
        ev_rows = cur.fetchall()

        if ev_rows:
            print(f"\n[Literature Evidence & Findings] ({len(ev_rows)} found)")
            print("-" * 65)
            for er in ev_rows[:4]:
                title, authors, year, finding, strength = er
                print(f"  ? Paper  : {authors.split(',')[0]} ({year}) - {title[:55]}...")
                print(f"    Finding: \"{finding[:90]}...\" [{strength} Evidence]")

        conn.close()

    print("=" * 65 + "\n")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python cli/search.py \"<keyword>\"")
        sys.exit(1)
    search_all(sys.argv[1])
