#!/usr/bin/env python3
"""
Literature Parser for Research Discovery Engine.

Parses literature markdown files, extracts bibliographic metadata, concepts,
scientific findings, and candidate survey variables, then updates:
  - database/evidence.db (SQLite)
  - literature/index.json (JSON index)
"""

import os
import re
import json
import sqlite3
import yaml
from pathlib import Path
from typing import Dict, List, Any, Optional

DB_PATH = Path("database/evidence.db")
PAPERS_DIR = Path("literature/papers")
INDEX_PATH = Path("literature/index.json")

CONCEPT_DOMAIN_MAP = {
    "children_under5": ("Children Under Five / Balita", "Demografi & Kesehatan Anak"),
    "food_insecurity": ("Food Insecurity / Kerawanan Pangan (FIES)", "Pangan & Nutrisi"),
    "household_welfare": ("Household Welfare / Kesejahteraan RT", "Kesejahteraan Ekonomi"),
    "water_sanitation": ("WASH / Sanitasi & Air Bersih", "Sanitasi & WASH"),
    "rural_urban": ("Rural vs Urban Disparity", "Spasial & Geografi"),
    "social_assistance": ("Social Assistance / Bantuan Sosial (PKH, BPNT)", "Perlindungan Sosial"),
    "poverty": ("Poverty / Kemiskinan", "Kesejahteraan Ekonomi"),
    "food_expenditure_share": ("Food Expenditure Share / Pangsa Pangan", "Pengeluaran & Pangan"),
    "inequality": ("Inequality / Ketimpangan", "Kesejahteraan Ekonomi")
}

def parse_markdown_paper(file_path: Path) -> Optional[Dict[str, Any]]:
    """Parse a single markdown paper with YAML frontmatter."""
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    if not content.startswith("---"):
        print(f"[WARN] No YAML frontmatter found in {file_path}")
        return None

    parts = content.split("---", 2)
    if len(parts) < 3:
        print(f"[WARN] Invalid frontmatter format in {file_path}")
        return None

    frontmatter_raw = parts[1].strip()
    body = parts[2].strip()

    meta = yaml.safe_load(frontmatter_raw) or {}
    paper_id = meta.get("paper_id") or file_path.stem
    title = meta.get("title", "Untitled")
    year = int(meta.get("year", 2020))
    authors = meta.get("authors", "Unknown")
    source = meta.get("source", "Unknown")

    concepts = []
    if "## Concepts" in body:
        c_part = body.split("## Concepts", 1)[1]
        if "## " in c_part:
            c_part = c_part.split("## ", 1)[0]
        for line in c_part.strip().splitlines():
            line = line.strip().lstrip("-").strip()
            if line:
                concepts.append(line)

    findings = []
    if "## Findings" in body:
        f_part = body.split("## Findings", 1)[1]
        if "## " in f_part:
            f_part = f_part.split("## ", 1)[0]
        try:
            parsed = yaml.safe_load(f_part.strip())
            if isinstance(parsed, list):
                findings = parsed
        except Exception as e:
            print(f"[WARN] Failed to parse findings in {file_path}: {e}")

    return {
        "paper_id": paper_id,
        "title": title,
        "year": year,
        "authors": authors,
        "source": source,
        "file_path": str(file_path).replace("\\", "/"),
        "concepts": concepts,
        "findings": findings
    }

def update_evidence_db(papers: List[Dict[str, Any]], db_path: Path = DB_PATH):
    """Update SQLite evidence.db with parsed papers, concepts, findings, variables."""
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    for p in papers:
        cur.execute("""
            INSERT OR REPLACE INTO papers (paper_id, title, year, authors, source, file_path)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (p["paper_id"], p["title"], p["year"], p["authors"], p["source"], p["file_path"]))

        for cid in p["concepts"]:
            c_name, domain = CONCEPT_DOMAIN_MAP.get(cid, (cid.replace("_", " ").title(), "General"))
            cur.execute("""
                INSERT OR IGNORE INTO concepts (concept_id, concept, domain)
                VALUES (?, ?, ?)
            """, (cid, c_name, domain))

        for idx, f in enumerate(p["findings"]):
            fid = f"{p['paper_id']}_F{idx+1:02d}"
            finding_text = f.get("finding", "")
            cid = f.get("concept", p["concepts"][0] if p["concepts"] else "general")
            strength = f.get("evidence_strength", "Moderate")

            c_name, domain = CONCEPT_DOMAIN_MAP.get(cid, (cid.replace("_", " ").title(), "General"))
            cur.execute("""
                INSERT OR IGNORE INTO concepts (concept_id, concept, domain)
                VALUES (?, ?, ?)
            """, (cid, c_name, domain))

            cur.execute("""
                INSERT OR REPLACE INTO findings (finding_id, paper_id, concept_id, finding, evidence_strength)
                VALUES (?, ?, ?, ?, ?)
            """, (fid, p['paper_id'], cid, finding_text, strength))

            cur.execute("DELETE FROM finding_variables WHERE finding_id = ?", (fid,))

            for var in f.get("variables", []):
                cur.execute("""
                    INSERT INTO finding_variables (finding_id, variable_concept)
                    VALUES (?, ?)
                """, (fid, var))

    conn.commit()
    conn.close()

def build_index_json(papers: List[Dict[str, Any]], output_path: Path = INDEX_PATH):
    """Build inverted index.json for fast search and citation generation."""
    index_data = {
        "version": "1.0",
        "total_papers": len(papers),
        "papers": {},
        "concept_to_papers": {},
        "variable_to_papers": {}
    }

    for p in papers:
        pid = p["paper_id"]
        index_data["papers"][pid] = {
            "title": p["title"],
            "year": p["year"],
            "authors": p["authors"],
            "source": p["source"],
            "file_path": p["file_path"],
            "concepts": p["concepts"],
            "total_findings": len(p["findings"])
        }

        for cid in p["concepts"]:
            index_data["concept_to_papers"].setdefault(cid, []).append(pid)

        for f in p["findings"]:
            for v in f.get("variables", []):
                if pid not in index_data["variable_to_papers"].setdefault(v, []):
                    index_data["variable_to_papers"][v].append(pid)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(index_data, f, indent=2, ensure_ascii=False)

def run_parser():
    """Main execution function."""
    if not PAPERS_DIR.exists():
        print(f"[ERROR] Directory not found: {PAPERS_DIR}")
        return []

    parsed_papers = []
    for f in sorted(PAPERS_DIR.glob("*.md")):
        paper = parse_markdown_paper(f)
        if paper:
            parsed_papers.append(paper)

    print(f">> Successfully parsed {len(parsed_papers)} literature paper(s).")
    update_evidence_db(parsed_papers)
    build_index_json(parsed_papers)
    print(f">> Updated {DB_PATH} and {INDEX_PATH}")
    return parsed_papers

if __name__ == "__main__":
    run_parser()
