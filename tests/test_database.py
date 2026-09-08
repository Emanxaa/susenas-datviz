import sqlite3
from pathlib import Path

def test_metadata_db_exists_and_valid():
    db = Path("database/metadata.db")
    assert db.exists(), "metadata.db must exist"
    conn = sqlite3.connect(db)
    cur = conn.cursor()
    tables = {r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
    conn.close()
    
    expected = {"variable_compatibility", "survey_catalog", "variable_registry", "concept_registry"}
    assert expected.issubset(tables), f"Missing tables in metadata.db: {expected - tables}"

def test_evidence_db_exists_and_valid():
    db = Path("database/evidence.db")
    assert db.exists(), "evidence.db must exist"
    conn = sqlite3.connect(db)
    cur = conn.cursor()
    tables = {r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
    conn.close()
    
    expected = {"papers", "concepts", "findings", "finding_variables"}
    assert expected.issubset(tables), f"Missing tables in evidence.db: {expected - tables}"
