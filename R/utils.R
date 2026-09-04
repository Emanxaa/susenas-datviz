# R/utils.R
# Shared utility functions and database connection managers for SUSENAS workflows

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(readxl)
  library(tibble)
  library(purrr)
  library(stringr)
  library(tidyr)
})

# Path constants and dynamic resolver
resolve_db_path <- function(db_name = "susenas.db") {
  candidates <- c(
    file.path("database", db_name),
    file.path("..", "database", db_name),
    file.path("..", "..", "database", db_name),
    db_name
  )
  for (cand in candidates) {
    if (file.exists(cand)) return(normalizePath(cand, mustWork = TRUE))
  }
  file.path("database", db_name)
}

DB_METADATA_PATH <- resolve_db_path("metadata.db")
DB_SUSENAS_PATH  <- resolve_db_path("susenas.db")
SUSENAS_DATA_ROOT <- file.path("SUSENAS", "JAWA BARAT")

#' Get Metadata Database Connection
#' @param db_path Character path to metadata.db
#' @return DBIConnection object
get_metadata_con <- function(db_path = NULL) {
  target_path <- if (is.null(db_path)) resolve_db_path("metadata.db") else db_path
  if (!dir.exists(dirname(target_path))) {
    dir.create(dirname(target_path), recursive = TRUE, showWarnings = FALSE)
  }
  dbConnect(RSQLite::SQLite(), target_path)
}

#' Get Analytical Susenas Database Connection
#' @param db_path Character path to susenas.db
#' @return DBIConnection object
get_susenas_con <- function(db_path = NULL) {
  target_path <- if (is.null(db_path)) resolve_db_path("susenas.db") else db_path
  if (!dir.exists(dirname(target_path))) {
    dir.create(dirname(target_path), recursive = TRUE, showWarnings = FALSE)
  }
  dbConnect(RSQLite::SQLite(), target_path)
}

#' Safely execute query and disconnect
#' @param sql Character SQL statement
#' @param params List of parameters for query
#' @return data.frame
query_metadata <- function(sql, params = list()) {
  con <- get_metadata_con()
  on.exit(dbDisconnect(con), add = TRUE)
  if (length(params) > 0) {
    dbGetQuery(con, sql, params = params)
  } else {
    dbGetQuery(con, sql)
  }
}

#' Search variable registry by keyword or exact variable name
#' @param term Search keyword for label or variable name
#' @param module Optional module filter (e.g., 'kor_rt', 'kor_individu', 'kp_bp41')
#' @param year Optional year filter
#' @return tibble of matching variables
lookup_variable <- function(term, module = NULL, year = NULL) {
  sql <- "SELECT variable, label, module, year, data_type, metadata_source 
          FROM variable_registry 
          WHERE (variable LIKE :term OR label LIKE :term)"
  
  params <- list(term = paste0("%", term, "%"))
  
  if (!is.null(module)) {
    sql <- paste0(sql, " AND module = :module")
    params$module <- module
  }
  if (!is.null(year)) {
    sql <- paste0(sql, " AND year = :year")
    params$year <- year
  }
  
  sql <- paste0(sql, " ORDER BY year DESC, module, variable")
  as_tibble(query_metadata(sql, params))
}

#' Search value labels for a specific variable
#' @param var_name Variable name (e.g. 'R101', 'B4K2')
#' @param year Optional year filter
#' @return tibble of value code and label pairs
lookup_labels <- function(var_name, year = NULL) {
  sql <- "SELECT variable, value, label, module, year 
          FROM value_labels 
          WHERE variable = :var_name"
  params <- list(var_name = var_name)
  
  if (!is.null(year)) {
    sql <- paste0(sql, " AND year = :year")
    params$year <- year
  }
  
  sql <- paste0(sql, " ORDER BY year DESC, CAST(value AS INTEGER)")
  as_tibble(query_metadata(sql, params))
}

#' Retrieve registered join keys between two tables
#' @param from_tbl Source table name
#' @param to_tbl Destination table name
#' @return tibble of join specifications
get_join_keys <- function(from_tbl, to_tbl) {
  sql <- "SELECT from_table, to_table, join_keys, join_type, confidence, relationship, notes 
          FROM join_registry 
          WHERE (from_table = :from_tbl AND to_table = :to_tbl)
             OR (from_table = :to_tbl AND to_table = :from_tbl)"
  as_tibble(query_metadata(sql, list(from_tbl = from_tbl, to_tbl = to_tbl)))
}

# Standard dictionary of Jawa Barat Regencies and Cities (32 BPS Code)
JABAR_KABKOT_NAMES <- c(
  "1" = "Kab. Bogor", "2" = "Kab. Sukabumi", "3" = "Kab. Cianjur",
  "4" = "Kab. Bandung", "5" = "Kab. Garut", "6" = "Kab. Tasikmalaya",
  "7" = "Kab. Ciamis", "8" = "Kab. Kuningan", "9" = "Kab. Cirebon",
  "10" = "Kab. Majalengka", "11" = "Kab. Sumedang", "12" = "Kab. Indramayu",
  "13" = "Kab. Subang", "14" = "Kab. Purwakarta", "15" = "Kab. Karawang",
  "16" = "Kab. Bekasi", "17" = "Kab. Bandung Barat", "18" = "Kab. Pangandaran",
  "71" = "Kota Bogor", "72" = "Kota Sukabumi", "73" = "Kota Bandung",
  "74" = "Kota Cirebon", "75" = "Kota Bekasi", "76" = "Kota Depok",
  "77" = "Kota Cimahi", "78" = "Kota Tasikmalaya", "79" = "Kota Banjar"
)

# Canonical mapping between view column aliases and raw questionnaire variables
COLUMN_TO_METADATA_VAR <- c(
  "KLASIFIKASI_PERKOTAAN_PERDESAAN" = "R105",
  "TIPE_DAERAH"                     = "R105",
  "KODE_PROV"                      = "R101",
  "KODE_KABKOT"                    = "R102",
  "NO_ART"                         = "R401",
  "HUBUNGAN_KRT"                   = "R403",
  "STATUS_KAWIN"                   = "R404",
  "STATUS_KAWIN_KRT"               = "R404",
  "JENIS_KELAMIN"                  = "R405",
  "JENIS_KELAMIN_KRT"              = "R405",
  "UMUR"                           = "R407",
  "UMUR_KRT"                       = "R407",
  "PENDIDIKAN_TERTINGGI"           = "R612",
  "PENDIDIKAN_TERTINGGI_KRT"       = "R612"
)

#' Map raw codes to descriptive labels using metadata.db and standard catalogs
#' @param var_name Name of variable (can be raw BPS code like R105 or semantic alias like KLASIFIKASI_PERKOTAAN_PERDESAAN)
#' @param values Vector of raw values / codes
#' @param year Optional survey year
#' @return Vector of mapped character labels
map_value_labels <- function(var_name, values, year = NULL) {
  if (is.null(values) || length(values) == 0) return(values)
  
  clean_var <- toupper(var_name)
  lookup_var <- if (clean_var %in% names(COLUMN_TO_METADATA_VAR)) {
    COLUMN_TO_METADATA_VAR[[clean_var]]
  } else {
    var_name
  }
  
  # Check special Jawa Barat regency catalog
  if (clean_var %in% c("KODE_KABKOT", "R102")) {
    str_vals <- as.character(as.integer(values))
    mapped <- JABAR_KABKOT_NAMES[str_vals]
    return(ifelse(is.na(mapped), paste("Kab/Kota", values), mapped))
  }
  
  # Check bansos / assistance indicator variables
  if (clean_var %in% c("R2204A", "R2207", "R2209A", "STATUS_PKH")) {
    str_vals <- as.character(values)
    mapped <- case_when(
      str_vals %in% c("1", "Ya") ~ "Penerima Bantuan",
      str_vals %in% c("0", "5", "Tidak") ~ "Bukan Penerima",
      TRUE ~ str_vals
    )
    return(mapped)
  }
  
  # Fetch from metadata.db value_labels
  labels_df <- tryCatch({
    lookup_labels(lookup_var, year = year)
  }, error = function(e) tibble())
  
  if (nrow(labels_df) > 0) {
    mapping <- labels_df %>%
      distinct(value, label, .keep_all = TRUE)
    
    val_map <- setNames(mapping$label, as.character(mapping$value))
    str_vals <- as.character(values)
    mapped <- val_map[str_vals]
    return(ifelse(is.na(mapped), str_vals, mapped))
  }
  
  as.character(values)
}

#' Retrieve registered semantic research concepts
#' @param domain Optional domain filter (e.g. 'Pangan & Nutrisi', 'Kesejahteraan Ekonomi')
#' @return tibble of concepts
get_concepts <- function(domain = NULL) {
  sql <- "SELECT concept_id, concept_name, domain, description, primary_variables, 
                 covariate_variables, required_modules, default_table, indicator_formula, 
                 filter_recommendation, recommended_viz, keywords 
          FROM concept_registry"
  params <- list()
  if (!is.null(domain)) {
    sql <- paste0(sql, " WHERE domain = :domain")
    params$domain <- domain
  }
  sql <- paste0(sql, " ORDER BY id")
  as_tibble(query_metadata(sql, params))
}

#' Retrieve cross-year variable compatibility matrix
#' @param var_concept Optional variable concept name pattern
#' @param domain Optional domain filter
#' @return tibble of compatibility records
get_variable_compatibility <- function(var_concept = NULL, domain = NULL) {
  sql <- "SELECT variable_concept, domain, var_2019, var_2020, var_2021, var_2022, var_2023, 
                 module, compatibility_status, value_coding_consistent, notes 
          FROM variable_compatibility"
  params <- list()
  conditions <- character(0)
  
  if (!is.null(var_concept)) {
    conditions <- c(conditions, "variable_concept LIKE :concept")
    params$concept <- paste0("%", var_concept, "%")
  }
  if (!is.null(domain)) {
    conditions <- c(conditions, "domain = :domain")
    params$domain <- domain
  }
  if (length(conditions) > 0) {
    sql <- paste0(sql, " WHERE ", paste(conditions, collapse = " AND "))
  }
  sql <- paste0(sql, " ORDER BY id")
  as_tibble(query_metadata(sql, params))
}
