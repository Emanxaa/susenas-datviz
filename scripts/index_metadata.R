# scripts/index_metadata.R
# SUSENAS Research Agent Discovery & Indexing Pipeline

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(readxl)
  library(dplyr)
  library(purrr)
  library(stringr)
})

con <- dbConnect(RSQLite::SQLite(), "database/metadata.db")

# Ensure tables exist
dbExecute(con, "
CREATE TABLE IF NOT EXISTS survey_catalog (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    year INTEGER,
    province TEXT,
    module TEXT,
    table_name TEXT,
    file_name TEXT,
    file_path TEXT,
    file_format TEXT,
    n_rows INTEGER,
    n_cols INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);")

dbExecute(con, "
CREATE TABLE IF NOT EXISTS variable_registry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    variable TEXT NOT NULL,
    label TEXT,
    module TEXT,
    year INTEGER,
    data_type TEXT,
    description TEXT,
    metadata_source TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);")

dbExecute(con, "
CREATE TABLE IF NOT EXISTS value_labels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    variable TEXT NOT NULL,
    value TEXT NOT NULL,
    label TEXT NOT NULL,
    module TEXT,
    year INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);")

dbExecute(con, "
CREATE TABLE IF NOT EXISTS join_registry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    from_table TEXT NOT NULL,
    to_table TEXT NOT NULL,
    join_keys TEXT NOT NULL,
    join_type TEXT DEFAULT 'INNER',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);")

# Standard join configurations
register_standard_joins <- function(con) {
  existing <- dbGetQuery(con, "SELECT COUNT(*) as count FROM join_registry")
  if (existing$count == 0) {
    joins <- data.frame(
      from_table = c("kor_rt", "kor_rt", "kor_individu"),
      to_table = c("kor_individu", "kp_bp41", "kp_bp41"),
      join_keys = c("[\"URUT\", \"TAHUN\"]", "[\"URUT\", \"TAHUN\"]", "[\"URUT\", \"TAHUN\"]"),
      join_type = c("INNER", "INNER", "INNER"),
      notes = c(
        "Household to individual linkage via sample sequence (URUT) and survey year",
        "Household to consumption/expenditure module linkage",
        "Individual to household expenditure linkage"
      ),
      stringsAsFactors = FALSE
    )
    dbWriteTable(con, "join_registry", joins, append = TRUE)
  }
}

register_standard_joins(con)

# Scan workspace
susenas_root <- "SUSENAS/JAWA BARAT"
if (dir.exists(susenas_root)) {
  message("Scanning SUSENAS directory: ", susenas_root)
  years <- list.dirs(susenas_root, recursive = FALSE, full.names = FALSE)
  years <- years[grepl("^[0-9]{4}$", years)]
  
  for (yr in years) {
    yr_num <- as.integer(yr)
    yr_dir <- file.path(susenas_root, yr)
    
    # 1. Scan metadata files
    meta_dir <- file.path(yr_dir, "Metadata dan Kuisioner")
    if (!dir.exists(meta_dir)) {
      meta_candidates <- list.dirs(yr_dir, recursive = TRUE)
      meta_dir <- meta_candidates[grepl("metadata", meta_candidates, ignore.case = TRUE)][1]
    }
    
    if (!is.na(meta_dir) && dir.exists(meta_dir)) {
      layout_files <- list.files(meta_dir, pattern = "Layout.*\\.xlsx?$", full.names = TRUE, ignore.case = TRUE)
      for (lf in layout_files) {
        sheets <- excel_sheets(lf)
        for (sh in sheets) {
          df_sheet <- tryCatch(read_excel(lf, sheet = sh, n_max = 5000), error = function(e) NULL)
          if (!is.null(df_sheet) && nrow(df_sheet) > 0) {
            # Normalize column names
            colnames(df_sheet) <- tolower(colnames(df_sheet))
            var_col <- names(df_sheet)[grepl("var|nama|kode", names(df_sheet))][1]
            lbl_col <- names(df_sheet)[grepl("ket|label|deskripsi|keterangan", names(df_sheet))][1]
            
            if (!is.na(var_col) && !is.na(lbl_col)) {
              vars_to_add <- df_sheet %>%
                select(variable = !!sym(var_col), label = !!sym(lbl_col)) %>%
                filter(!is.na(variable), variable != "") %>%
                mutate(
                  module = sh,
                  year = yr_num,
                  data_type = NA_character_,
                  description = NA_character_,
                  metadata_source = basename(lf)
                ) %>%
                distinct(variable, year, module, .keep_all = TRUE)
              
              dbWriteTable(con, "variable_registry", vars_to_add, append = TRUE)
            }
          }
        }
      }
    }
    
    # 2. Scan CSV data files
    csv_files <- list.files(yr_dir, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
    for (cf in csv_files) {
      fname <- basename(cf)
      mod_name <- case_when(
        grepl("rt|rumah.*tangga", fname, ignore.case = TRUE) ~ "kor_rt",
        grepl("ind|individu", fname, ignore.case = TRUE) ~ "kor_individu",
        grepl("bp.*4.?1|41", fname, ignore.case = TRUE) ~ "kp_bp41",
        grepl("bp.*4.?2|42", fname, ignore.case = TRUE) ~ "kp_bp42",
        grepl("bp.*4.?3|43", fname, ignore.case = TRUE) ~ "kp_bp43",
        TRUE ~ tools::file_path_sans_ext(fname)
      )
      
      cat_entry <- data.frame(
        year = yr_num,
        province = "JAWA BARAT",
        module = mod_name,
        table_name = tolower(paste0(mod_name, "_", yr_num)),
        file_name = fname,
        file_path = cf,
        file_format = "csv",
        n_rows = NA_integer_,
        n_cols = NA_integer_,
        stringsAsFactors = FALSE
      )
      dbWriteTable(con, "survey_catalog", cat_entry, append = TRUE)
    }
  }
  message("Indexing complete.")
} else {
  message("Workspace '", susenas_root, "' not found yet. Schema and join registry initialized.")
}

dbDisconnect(con)
