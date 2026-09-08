#!/usr/bin/env python3
"""
Feature Master Generator for SUSENAS Research Discovery Engine.

Takes candidate variables and concepts, queries variable_compatibility in metadata.db,
and outputs a comprehensive cross-year compatibility markdown table.
"""

import sqlite3
from pathlib import Path
from typing import List, Dict, Any, Optional

METADATA_DB = Path("database/metadata.db")
DEFAULT_REPORT_PATH = Path("reports/feature_master.md")

def generate_feature_master(
    candidate_variables: List[str],
    concepts: Optional[List[str]] = None,
    output_path: Optional[Path] = DEFAULT_REPORT_PATH
) -> Dict[str, Any]:
    """Generate cross-year feature master matrix from variable_compatibility."""
    conn = sqlite3.connect(METADATA_DB)
    cur = conn.cursor()

    # Fetch all records from variable_compatibility
    query_all = """
        SELECT variable_concept, domain, var_2019, var_2020, var_2021, var_2022, var_2023,
               module, compatibility_status, notes
        FROM variable_compatibility
    """
    all_rows = cur.execute(query_all).fetchall()
    conn.close()

    # Match candidate variables to rows
    matched_rows = []
    seen_concepts = set()

    cand_upper = set(v.upper() for v in candidate_variables)

    for row in all_rows:
        v_concept, domain, v19, v20, v21, v22, v23, mod, status, notes = row
        years_vars = [v19.upper(), v20.upper(), v21.upper(), v22.upper(), v23.upper()]

        # Check if any candidate variable appears in any year variable column
        matched = False
        for cand in cand_upper:
            # Exact or substring match in year vars (e.g. R1701 in R1701-R1708)
            for yv in years_vars:
                if cand == yv or cand in yv.split() or cand in yv.split('-') or cand in yv.split('/'):
                    matched = True
                    break
            if matched:
                break

        if matched and v_concept not in seen_concepts:
            seen_concepts.add(v_concept)
            matched_rows.append({
                "concept": v_concept,
                "domain": domain,
                "var_2019": v19,
                "var_2020": v20,
                "var_2021": v21,
                "var_2022": v22,
                "var_2023": v23,
                "module": mod,
                "status": status,
                "notes": notes or ""
            })

    # Always ensure baseline identifiers (URUT, R102, R105, WERT) are included if in all_rows
    baseline_concepts = ["Nomor Urut Rumah Tangga (Join Key)", "Kode Kabupaten / Kota", "Klasifikasi Perkotaan / Perdesaan", "Penimbang Rumah Tangga (Sampling Weight)"]
    for row in all_rows:
        v_concept = row[0]
        if v_concept in baseline_concepts and v_concept not in seen_concepts:
            seen_concepts.add(v_concept)
            matched_rows.insert(0, {
                "concept": v_concept,
                "domain": row[1],
                "var_2019": row[2],
                "var_2020": row[3],
                "var_2021": row[4],
                "var_2022": row[5],
                "var_2023": row[6],
                "module": row[7],
                "status": row[8],
                "notes": row[9] or ""
            })

    # Build Markdown table
    md_lines = [
        "# Master Matrix Kompatibilitas Fitur SUSENAS (2019?2023)",
        "",
        "> Disusun otomatis oleh Feature Master Generator (Research Discovery Engine).",
        "> Menampilkan pemetaan variabel survei resmi BPS lintas tahun untuk memastikan konsistensi ekstraksi.",
        "",
        "| Konsep / Fitur | 2019 | 2020 | 2021 | 2022 | 2023 | Modul Sumber | Status Kompatibilitas |",
        "|:---|:---:|:---:|:---:|:---:|:---:|:---|:---:|"
    ]

    for r in matched_rows:
        line = f"| **{r['concept']}** | `{r['var_2019']}` | `{r['var_2020']}` | `{r['var_2021']}` | `{r['var_2022']}` | `{r['var_2023']}` | {r['module']} | {r['status']} |"
        md_lines.append(line)

    md_lines.append("")
    md_lines.append("### Catatan Teknis:")
    for r in matched_rows:
        if r['notes']:
            md_lines.append(f"- **{r['concept']}**: {r['notes']}")

    markdown_text = "\n".join(md_lines) + "\n"

    if output_path:
        out_p = Path(output_path)
        out_p.parent.mkdir(parents=True, exist_ok=True)
        with open(out_p, "w", encoding="utf-8") as f:
            f.write(markdown_text)
        # print(f">> Feature master report saved to: {out_p}")

    return {
        "total_matched_features": len(matched_rows),
        "rows": matched_rows,
        "markdown": markdown_text
    }

if __name__ == "__main__":
    import sys
    test_vars = ["URUT", "R102", "R105", "WERT", "R407", "R1701", "R1702", "KALORI_KAP", "FOOD"]
    res = generate_feature_master(test_vars)
    print(f"Generated feature master with {res['total_matched_features']} features.")
