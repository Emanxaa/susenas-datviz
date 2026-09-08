-- Migration 001: Schema for evidence.db (Literature Knowledge Base)

CREATE TABLE IF NOT EXISTS papers (
    paper_id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    year INTEGER NOT NULL,
    authors TEXT NOT NULL,
    source TEXT NOT NULL,
    file_path TEXT
);

CREATE TABLE IF NOT EXISTS concepts (
    concept_id TEXT PRIMARY KEY,
    concept TEXT NOT NULL,
    domain TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS findings (
    finding_id TEXT PRIMARY KEY,
    paper_id TEXT NOT NULL,
    concept_id TEXT NOT NULL,
    finding TEXT NOT NULL,
    evidence_strength TEXT NOT NULL,
    FOREIGN KEY(paper_id) REFERENCES papers(paper_id),
    FOREIGN KEY(concept_id) REFERENCES concepts(concept_id)
);

CREATE TABLE IF NOT EXISTS finding_variables (
    finding_id TEXT NOT NULL,
    variable_concept TEXT NOT NULL,
    FOREIGN KEY(finding_id) REFERENCES findings(finding_id)
);

CREATE INDEX IF NOT EXISTS idx_findings_concept ON findings(concept_id);
CREATE INDEX IF NOT EXISTS idx_findings_paper ON findings(paper_id);
CREATE INDEX IF NOT EXISTS idx_finding_var ON finding_variables(variable_concept);
