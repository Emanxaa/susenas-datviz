# R/00_setup.R
# Environment bootstrap, directory initialization, and metadata database schema creation

source("R/utils.R")

message(">> [Phase 2] Initializing workspace directories...")

required_dirs <- c(
  "database",
  "R",
  "output",
  "quarto",
  file.path("SUSENAS", "JAWA BARAT")
)

for (d in required_dirs) {
  if (!dir.exists(d)) {
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    message("   Created directory: ", d)
  }
}

# Ensure structure for years 2019-2023
for (yr in 2019:2023) {
  subdirs <- c(
    file.path("SUSENAS", "JAWA BARAT", yr, "csv", "KOR"),
    file.path("SUSENAS", "JAWA BARAT", yr, "csv", "Modul KP"),
    file.path("SUSENAS", "JAWA BARAT", yr, "dbf"),
    file.path("SUSENAS", "JAWA BARAT", yr, "Metadata dan Kuisioner")
  )
  for (sd in subdirs) {
    if (!dir.exists(sd)) {
      dir.create(sd, recursive = TRUE, showWarnings = FALSE)
    }
  }
}

message(">> [Phase 3] Bootstrapping SQLite database schema at: ", DB_METADATA_PATH)

con <- get_metadata_con()

# 1. survey_catalog
dbExecute(con, "
CREATE TABLE IF NOT EXISTS survey_catalog (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    year INTEGER NOT NULL,
    province TEXT NOT NULL,
    module TEXT NOT NULL,
    table_name TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_format TEXT NOT NULL,
    n_rows INTEGER,
    n_cols INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(year, province, module, file_name)
);")

# 2. variable_registry
dbExecute(con, "
CREATE TABLE IF NOT EXISTS variable_registry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    variable TEXT NOT NULL,
    label TEXT,
    module TEXT NOT NULL,
    year INTEGER NOT NULL,
    data_type TEXT,
    description TEXT,
    metadata_source TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(variable, module, year)
);")

# 3. value_labels
dbExecute(con, "
CREATE TABLE IF NOT EXISTS value_labels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    variable TEXT NOT NULL,
    value TEXT NOT NULL,
    label TEXT NOT NULL,
    module TEXT NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(variable, value, module, year)
);")

# 4. join_registry
dbExecute(con, "
CREATE TABLE IF NOT EXISTS join_registry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    from_table TEXT NOT NULL,
    to_table TEXT NOT NULL,
    join_keys TEXT NOT NULL,
    join_type TEXT DEFAULT 'INNER',
    confidence REAL DEFAULT 1.0,
    relationship TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(from_table, to_table, join_keys)
);")

# Create indices for sub-millisecond retrieval
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_var_name ON variable_registry(variable);")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_var_mod_yr ON variable_registry(module, year);")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_val_lbl_var ON value_labels(variable, year);")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_cat_yr_mod ON survey_catalog(year, module);")

dbDisconnect(con)

# Initialize analytical database
con_susenas <- get_susenas_con()
dbDisconnect(con_susenas)

message(">> [Setup Completed] Metadata tables and analytical databases ready.")
