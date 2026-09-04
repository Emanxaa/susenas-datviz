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

# Path constants
DB_METADATA_PATH <- file.path("database", "metadata.db")
DB_SUSENAS_PATH  <- file.path("database", "susenas.db")
SUSENAS_DATA_ROOT <- file.path("SUSENAS", "JAWA BARAT")

#' Get Metadata Database Connection
#' @param db_path Character path to metadata.db
#' @return DBIConnection object
get_metadata_con <- function(db_path = DB_METADATA_PATH) {
  if (!dir.exists(dirname(db_path))) {
    dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)
  }
  dbConnect(RSQLite::SQLite(), db_path)
}

#' Get Analytical Susenas Database Connection
#' @param db_path Character path to susenas.db
#' @return DBIConnection object
get_susenas_con <- function(db_path = DB_SUSENAS_PATH) {
  if (!dir.exists(dirname(db_path))) {
    dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)
  }
  dbConnect(RSQLite::SQLite(), db_path)
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
