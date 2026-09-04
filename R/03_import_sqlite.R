# R/03_import_sqlite.R
# Production SQLite Ingestion Pipeline for SUSENAS Jawa Barat
# Imports CSV files lazily by year, preserves column names, creates indexes on join keys,
# builds reusable analytical views, and produces detailed loading reports.

source("R/utils.R")

suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(tibble)
  library(stringr)
})

#' Helper to determine table name from file and year
get_table_name <- function(file_name, year) {
  fn <- tolower(file_name)
  mod <- case_when(
    grepl("individu.*part.?1|ind1", fn)          ~ "kor_ind1",
    grepl("individu.*part.?2|ind2", fn)          ~ "kor_ind2",
    grepl("rumah.*tangga|\\bkor_rt\\b|\\brt\\b", fn) ~ "kor_rt",
    grepl("bp.*4.?1|41", fn)                     ~ "kp_bp41",
    grepl("bp.*4.?2|42", fn)                     ~ "kp_bp42",
    grepl("bp.*4.?3|43", fn)                     ~ "kp_bp43",
    TRUE ~ gsub("[^a-z0-9_]", "_", tools::file_path_sans_ext(fn))
  )
  paste0(mod, "_", year)
}

#' Create indexes on join keys for an imported table
create_indexes_for_table <- function(con_susenas, table_name) {
  cols <- dbListFields(con_susenas, table_name)
  indexed <- character(0)
  
  # 1. URUT (Primary Household Linkage Key)
  if ("URUT" %in% cols) {
    idx_name <- paste0("idx_", table_name, "_urut")
    dbExecute(con_susenas, sprintf("CREATE INDEX IF NOT EXISTS %s ON %s (URUT);", idx_name, table_name))
    indexed <- c(indexed, "URUT")
  }
  
  # 2. R101, R102 (Geographic Hierarchy: Province + District/City)
  if (all(c("R101", "R102") %in% cols)) {
    idx_name <- paste0("idx_", table_name, "_geo")
    dbExecute(con_susenas, sprintf("CREATE INDEX IF NOT EXISTS %s ON %s (R101, R102);", idx_name, table_name))
    indexed <- c(indexed, "R101, R102")
  }
  
  # 3. Individual ART identifier (URUT + R401)
  if (all(c("URUT", "R401") %in% cols)) {
    idx_name <- paste0("idx_", table_name, "_art")
    dbExecute(con_susenas, sprintf("CREATE INDEX IF NOT EXISTS %s ON %s (URUT, R401);", idx_name, table_name))
    indexed <- c(indexed, "URUT, R401")
  }
  
  # 4. Household Head Filter (R403: 1 = Kepala Rumah Tangga)
  if ("R403" %in% cols) {
    idx_name <- paste0("idx_", table_name, "_r403")
    dbExecute(con_susenas, sprintf("CREATE INDEX IF NOT EXISTS %s ON %s (R403);", idx_name, table_name))
    indexed <- c(indexed, "R403")
  }
  
  # 5. Survey Sampling Frame (PSU, SSU)
  if (all(c("PSU", "SSU") %in% cols)) {
    idx_name <- paste0("idx_", table_name, "_sampling")
    dbExecute(con_susenas, sprintf("CREATE INDEX IF NOT EXISTS %s ON %s (PSU, SSU);", idx_name, table_name))
    indexed <- c(indexed, "PSU, SSU")
  }
  
  indexed
}

#' Import a single dataset lazily into SQLite
import_dataset <- function(file_path, table_name, con_susenas, force = FALSE) {
  # Check if table already exists and is populated
  table_exists <- dbExistsTable(con_susenas, table_name)
  
  if (table_exists && !force) {
    row_count <- dbGetQuery(con_susenas, sprintf("SELECT COUNT(*) as n FROM %s", table_name))$n
    if (row_count > 0) {
      cols <- length(dbListFields(con_susenas, table_name))
      return(list(
        table = table_name,
        rows = row_count,
        cols = cols,
        status = "SKIPPED (already loaded)",
        indexed = create_indexes_for_table(con_susenas, table_name)
      ))
    }
  }
  
  message(sprintf("   Reading %s -> table: %s ...", basename(file_path), table_name))
  
  # Fast multi-threaded reading preserving original column names
  dt <- data.table::fread(file_path, data.table = FALSE, showProgress = FALSE)
  
  # If first column is an unnamed row number (e.g. V1 with values 0, 1, 2...), remove it
  if (names(dt)[1] == "V1" && is.numeric(dt[[1]]) && identical(dt[[1]][1:min(5, nrow(dt))], as.numeric(0:(min(5, nrow(dt)) - 1)))) {
    dt <- dt[, -1, drop = FALSE]
  }
  
  # Write table directly to SQLite
  dbWriteTable(con_susenas, table_name, dt, overwrite = TRUE)
  
  # Create indexes on join keys
  indexed <- create_indexes_for_table(con_susenas, table_name)
  
  list(
    table = table_name,
    rows = nrow(dt),
    cols = ncol(dt),
    status = "IMPORTED",
    indexed = indexed
  )
}

#' Create reusable SQLite views for frequently joined tables in a given year
create_analytical_views <- function(con_susenas, year) {
  tbls <- dbListTables(con_susenas)
  views_created <- character(0)
  
  rt_tbl   <- paste0("kor_rt_", year)
  ind1_tbl <- paste0("kor_ind1_", year)
  ind2_tbl <- paste0("kor_ind2_", year)
  kp43_tbl <- paste0("kp_bp43_", year)
  kp41_tbl <- paste0("kp_bp41_", year)
  kp42_tbl <- paste0("kp_bp42_", year)
  
  # 1. View: Household Welfare + Total Expenditure
  if (all(c(rt_tbl, kp43_tbl) %in% tbls)) {
    view_name <- paste0("v_household_expenditure_", year)
    view_sql <- sprintf("
      CREATE VIEW IF NOT EXISTS %s AS
      SELECT 
        r.URUT,
        r.R101 AS KODE_PROV,
        r.R102 AS KODE_KABKOT,
        r.R105 AS KLASIFIKASI_PERKOTAAN_PERDESAAN,
        r.R1701 AS JUMLAH_ART,
        k.FOOD AS PENGELUARAN_MAKANAN,
        k.NONFOOD AS PENGELUARAN_NON_MAKANAN,
        k.EXPEND AS TOTAL_PENGELUARAN,
        k.KAPITA AS PENGELUARAN_PERKAPITA,
        k.KALORI_KAP AS KONSUMSI_KALORI_PERKAPITA,
        k.PROTE_KAP AS KONSUMSI_PROTEIN_PERKAPITA,
        k.WERT AS PENIMBANG_RT,
        r.*
      FROM %s r
      INNER JOIN %s k ON r.URUT = k.URUT;
    ", view_name, rt_tbl, kp43_tbl)
    
    dbExecute(con_susenas, sprintf("DROP VIEW IF EXISTS %s;", view_name))
    dbExecute(con_susenas, view_sql)
    views_created <- c(views_created, view_name)
  }
  
  # 2. View: Kepala Rumah Tangga (KRT) Demographics + Household Expenditure
  if (all(c(rt_tbl, ind1_tbl, kp43_tbl) %in% tbls)) {
    view_name <- paste0("v_head_household_welfare_", year)
    view_sql <- sprintf("
      CREATE VIEW IF NOT EXISTS %s AS
      SELECT 
        r.URUT,
        r.R101 AS KODE_PROV,
        r.R102 AS KODE_KABKOT,
        r.R105 AS KLASIFIKASI_PERKOTAAN_PERDESAAN,
        i.R401 AS NO_ART_KRT,
        i.R404 AS JENIS_KELAMIN_KRT,
        i.R405 AS UMUR_KRT,
        i.R407 AS STATUS_KAWIN_KRT,
        i.R612 AS PENDIDIKAN_TERTINGGI_KRT,
        k.FOOD AS PENGELUARAN_MAKANAN,
        k.NONFOOD AS PENGELUARAN_NON_MAKANAN,
        k.EXPEND AS TOTAL_PENGELUARAN,
        k.KAPITA AS PENGELUARAN_PERKAPITA,
        k.KALORI_KAP AS KALORI_PERKAPITA,
        k.PROTE_KAP AS PROTEIN_PERKAPITA,
        k.WERT AS PENIMBANG_RT
      FROM %s r
      INNER JOIN %s i ON r.URUT = i.URUT AND i.R403 = 1
      INNER JOIN %s k ON r.URUT = k.URUT;
    ", view_name, rt_tbl, ind1_tbl, kp43_tbl)
    
    dbExecute(con_susenas, sprintf("DROP VIEW IF EXISTS %s;", view_name))
    dbExecute(con_susenas, view_sql)
    views_created <- c(views_created, view_name)
  }
  
  # 3. View: Individual + Household Demographics
  if (all(c(rt_tbl, ind1_tbl) %in% tbls)) {
    view_name <- paste0("v_individual_household_", year)
    view_sql <- sprintf("
      CREATE VIEW IF NOT EXISTS %s AS
      SELECT 
        i.URUT,
        i.R401 AS NO_ART,
        i.R403 AS HUBUNGAN_KRT,
        i.R404 AS JENIS_KELAMIN,
        i.R405 AS UMUR,
        i.R407 AS STATUS_KAWIN,
        i.R612 AS PENDIDIKAN_TERTINGGI,
        r.R101 AS KODE_PROV,
        r.R102 AS KODE_KABKOT,
        r.R105 AS TIPE_DAERAH,
        r.R1701 AS TOTAL_ART_RT
      FROM %s i
      INNER JOIN %s r ON i.URUT = r.URUT;
    ", view_name, ind1_tbl, rt_tbl)
    
    dbExecute(con_susenas, sprintf("DROP VIEW IF EXISTS %s;", view_name))
    dbExecute(con_susenas, view_sql)
    views_created <- c(views_created, view_name)
  }
  
  views_created
}

#' Main orchestrator to lazily import SUSENAS datasets for a given year
import_susenas_year <- function(year = 2023, susenas_root = "SUSENAS/JAWA BARAT", force = FALSE) {
  message(sprintf("======================================================================"))
  message(sprintf(">> [Lazy Ingestion] Starting SQLite build for Year: %d", year))
  message(sprintf("======================================================================"))
  
  yr_dir <- file.path(susenas_root, year)
  if (!dir.exists(yr_dir)) {
    warning(sprintf("Directory for year %d not found at: %s", year, yr_dir))
    return(NULL)
  }
  
  con_susenas <- get_susenas_con()
  on.exit(dbDisconnect(con_susenas), add = TRUE)
  
  # Priority rule: CSV is analysis source. Never import DBF if CSV exists.
  csv_files <- list.files(file.path(yr_dir, "csv"), pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
  dbf_files <- list.files(file.path(yr_dir, "dbf"), pattern = "\\.dbf$", recursive = TRUE, full.names = TRUE)
  
  files_to_import <- list()
  
  if (length(csv_files) > 0) {
    message(sprintf("   Found %d CSV files. (Ignoring DBF as CSV is present).", length(csv_files)))
    for (cf in csv_files) {
      files_to_import[[length(files_to_import) + 1]] <- list(path = cf, format = "csv")
    }
  } else if (length(dbf_files) > 0) {
    message(sprintf("   No CSV found. Fallback to %d DBF files.", length(dbf_files)))
    for (df in dbf_files) {
      files_to_import[[length(files_to_import) + 1]] <- list(path = df, format = "dbf")
    }
  } else {
    message(sprintf("   No data files (.csv or .dbf) found locally for year %d.", year))
    return(NULL)
  }
  
  report_rows <- list()
  
  for (item in files_to_import) {
    f_path <- item$path
    f_name <- basename(f_path)
    tbl_name <- get_table_name(f_name, year)
    
    res <- import_dataset(f_path, tbl_name, con_susenas, force = force)
    
    report_rows[[length(report_rows) + 1]] <- tibble(
      Table = res$table,
      Source_File = f_name,
      Status = res$status,
      Rows = res$rows,
      Columns = res$cols,
      Indexes_Created = paste(res$indexed, collapse = " | ")
    )
    
    # Update survey_catalog with actual row and column counts
    con_meta <- get_metadata_con()
    tryCatch({
      dbExecute(con_meta, "
        UPDATE survey_catalog 
        SET n_rows = :n_rows, n_cols = :n_cols 
        WHERE year = :year AND table_name = :tbl_name;
      ", params = list(n_rows = res$rows, n_cols = res$cols, year = year, tbl_name = tbl_name))
    }, finally = {
      dbDisconnect(con_meta)
    })
  }
  
  report_df <- bind_rows(report_rows)
  
  # Create reusable analytical views
  views <- create_analytical_views(con_susenas, year)
  
  # Print Loading Report
  cat("\n======================================================================\n")
  cat(sprintf("   SUSENAS %d SQLite INGESTION REPORT (database/susenas.db)\n", year))
  cat("======================================================================\n\n")
  print(as.data.frame(report_df), row.names = FALSE)
  
  cat("\n----------------------------------------------------------------------\n")
  cat(">> Reusable SQLite Views Created:\n")
  for (v in views) {
    cat(sprintf("   - %s\n", v))
  }
  cat("----------------------------------------------------------------------\n\n")
  
  invisible(list(report = report_df, views = views))
}

# Standalone execution: default to Year 2023
if (sys.nframe() == 0) {
  import_susenas_year(year = 2023, force = FALSE)
}
