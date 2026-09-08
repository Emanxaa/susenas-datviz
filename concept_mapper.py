#!/usr/bin/env python3
"""
Concept Mapper for SUSENAS Research Discovery Engine.

Maps free-form research questions or concept keys into:
1. Standardized semantic concept IDs
2. Scientific evidence findings from evidence.db
3. Candidate survey variables from metadata.db and literature findings
"""

import re
import sys
import json
import sqlite3
from pathlib import Path
from typing import Dict, List, Set, Any, Optional

EVIDENCE_DB = Path("database/evidence.db")
METADATA_DB = Path("database/metadata.db")

# Comprehensive Synonym & Keyword Dictionary
SYNONYM_DICTIONARY = {
    "children_under5": [
        "balita", "anak balita", "anak usia dini", "bayi", "batita", "under-five",
        "toddler", "infant", "anak kecil", "stunting", "gizi balita", "anak"
    ],
    "food_insecurity": [
        "kerawanan pangan", "rawan pangan", "ketahanan pangan", "kelaparan",
        "kurang pangan", "fies", "food insecurity", "food security", "hunger",
        "nutrisi", "gizi", "konsumsi makanan", "kalori", "protein"
    ],
    "water_sanitation": [
        "air", "air bersih", "air minum", "sanitasi", "jamban", "kloset",
        "tangki septik", "wash", "tinja", "bab", "buang air besar", "toilet"
    ],
    "social_assistance": [
        "bansos", "bantuan sosial", "pkh", "bpnt", "sembako", "kartu sembako",
        "blt", "subsidi", "social assistance", "bantuan pangan", "bantuan tunai"
    ],
    "food_expenditure_share": [
        "pangsa pangan", "pangsa pengeluaran pangan", "hukum engel", "engel",
        "proporsi makanan", "belanja makanan", "beban pangan", "food expenditure"
    ],
    "household_welfare": [
        "kemiskinan", "miskin", "kesejahteraan", "poverty", "garis kemiskinan",
        "pengeluaran per kapita", "desil", "kuintil", "welfare"
    ],
    "education_head": [
        "pendidikan", "sekolah", "ijazah", "tamat sd", "smp", "sma", "sarjana",
        "krt sekolah", "education", "human capital"
    ],
    "rural_urban": [
        "desa", "kota", "desa kota", "perdesaan", "perkotaan", "disparitas",
        "wilayah", "kabupaten", "rural", "urban"
    ]
}

# Concept to Core Default Variables fallback
DEFAULT_CONCEPT_VARS = {
    "children_under5": ["R407", "R301", "JART014"],
    "food_insecurity": ["R1701", "R1702", "R1703", "R1704", "R1705", "R1706", "R1707", "R1708", "KALORI_KAP", "PROTE_KAP", "FOOD"],
    "water_sanitation": ["R1809A", "R1809B", "R1809C", "R1810A"],
    "social_assistance": ["R2204A", "R2207", "R2209A"],
    "food_expenditure_share": ["FOOD", "EXPEND", "KAPITA"],
    "household_welfare": ["KAPITA", "EXPEND", "R301"],
    "education_head": ["R612", "R614", "R403"],
    "rural_urban": ["R105", "R102", "WERT"]
}

def map_query(text: str) -> Dict[str, Any]:
    """Map free-text query string to standardized concepts and candidate variables."""
    text_lower = text.lower()
    matched_concepts = set()

    # 1. Match against synonym dictionary
    for cid, synonyms in SYNONYM_DICTIONARY.items():
        for syn in synonyms:
            pattern = r'\b' + re.escape(syn) + r'\b'
            if re.search(pattern, text_lower):
                matched_concepts.add(cid)
                break

    # If direct concept ID is passed
    for cid in SYNONYM_DICTIONARY.keys():
        if cid in text_lower:
            matched_concepts.add(cid)

    concepts_list = sorted(list(matched_concepts))
    candidate_vars: Set[str] = set()
    supporting_papers: List[Dict[str, Any]] = []

    # 2. Query evidence.db if available
    if EVIDENCE_DB.exists():
        try:
            conn = sqlite3.connect(EVIDENCE_DB)
            cur = conn.cursor()
            for cid in concepts_list:
                q = """
                    SELECT p.paper_id, p.title, p.authors, p.year, f.finding, f.evidence_strength, v.variable_concept
                    FROM findings f
                    JOIN papers p ON f.paper_id = p.paper_id
                    LEFT JOIN finding_variables v ON f.finding_id = v.finding_id
                    WHERE f.concept_id = ?
                """
                rows = cur.execute(q, (cid,)).fetchall()
                for r in rows:
                    pid, title, authors, year, finding, strength, var_c = r
                    if var_c:
                        candidate_vars.add(var_c)
                    # Add unique papers
                    if not any(sp['paper_id'] == pid for sp in supporting_papers):
                        supporting_papers.append({
                            "paper_id": pid,
                            "title": title,
                            "authors": authors,
                            "year": year
                        })
            conn.close()
        except Exception as e:
            print(f"[WARN] Error querying evidence.db: {e}", file=sys.stderr)

    # 3. Add default concept vars to guarantee coverage
    for cid in concepts_list:
        for v in DEFAULT_CONCEPT_VARS.get(cid, []):
            candidate_vars.add(v)

    # Always ensure join and weighting primitives are present
    candidate_vars.update(["URUT", "R102", "R105", "WERT"])

    # Sort candidate variables keeping ID keys first
    priority_keys = ["URUT", "R101", "R102", "R105", "WERT", "R301"]
    sorted_vars = [v for v in priority_keys if v in candidate_vars] + [
        v for v in sorted(list(candidate_vars)) if v not in priority_keys
    ]

    return {
        "query": text,
        "concepts": concepts_list,
        "candidate_variables": sorted_vars,
        "supporting_papers": supporting_papers
    }

if __name__ == "__main__":
    query_input = sys.argv[1] if len(sys.argv) > 1 else 'anak balita dan kerawanan pangan'
    res = map_query(query_input)
    # Print JSON output exactly as requested in Phase 4 specification
    output_json = {
        "concepts": res["concepts"],
        "candidate_variables": res["candidate_variables"]
    }
    print(json.dumps(output_json, indent=2))
