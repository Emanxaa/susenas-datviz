# R/01_build_catalog.R
# Scan SUSENAS directory hierarchy and register all datasets into survey_catalog

source("R/utils.R")

message(">> [Phase 4] Scanning SUSENAS dataset repository...")

con <- get_metadata_con()
on.exit(dbDisconnect(con), add = TRUE)

root_dir <- "SUSENAS"

if (!dir.exists(root_dir)) {
  stop("Dataset directory '", root_dir, "' does not exist.")
}

all_files <- list.files(root_dir, recursive = TRUE, full.names = TRUE)

if (length(all_files) == 0) {
  message("   No files detected in ", root_dir)
} else {
  catalog_rows <- list()
  
  for (f in all_files) {
    norm_path <- normalizePath(f, winslash = "/", mustWork = FALSE)
    rel_path  <- gsub(paste0("^", normalizePath(".", winslash = "/"), "/"), "", norm_path)
    
    parts <- unlist(strsplit(rel_path, "/"))
    # Expected pattern: SUSENAS / PROVINCE / YEAR / ...
    if (length(parts) >= 3 && parts[1] == "SUSENAS") {
      province <- parts[2]
      year_str <- parts[3]
      year_val <- suppressWarnings(as.integer(year_str))
      
      if (!is.na(year_val)) {
        fname <- basename(f)
        ext   <- tolower(tools::file_ext(fname))
        
        # Module categorization
        module <- case_when(
          grepl("rumah.*tangga|kor.*rt|_rt\\b", fname, ignore.case = TRUE) ~ "kor_rt",
          grepl("individu|kor.*ind|_ind\\b", fname, ignore.case = TRUE) ~ "kor_individu",
          grepl("bp.*4.?1|41", fname, ignore.case = TRUE) ~ "kp_bp41",
          grepl("bp.*4.?2|42", fname, ignore.case = TRUE) ~ "kp_bp42",
          grepl("bp.*4.?3|43", fname, ignore.case = TRUE) ~ "kp_bp43",
          grepl("layout.*xlsx?", fname, ignore.case = TRUE) ~ "metadata_layout",
          grepl("vsen.*pdf", fname, ignore.case = TRUE) ~ "questionnaire_vsen",
          TRUE ~ tolower(tools::file_path_sans_ext(fname))
        )
        
        tbl_name <- paste0(module, "_", year_val)
        
        catalog_rows[[length(catalog_rows) + 1]] <- tibble(
          year = year_val,
          province = province,
          module = module,
          table_name = tbl_name,
          file_name = fname,
          file_path = rel_path,
          file_format = ext,
          n_rows = NA_integer_,
          n_cols = NA_integer_
        )
      }
    }
  }
  
  if (length(catalog_rows) > 0) {
    catalog_df <- bind_rows(catalog_rows) %>%
      distinct(year, province, module, file_name, .keep_all = TRUE)
    
    # Upsert into survey_catalog
    for (i in seq_len(nrow(catalog_df))) {
      row <- catalog_df[i, ]
      dbExecute(con, "
        INSERT INTO survey_catalog (year, province, module, table_name, file_name, file_path, file_format, n_rows, n_cols)
        VALUES (:year, :province, :module, :table_name, :file_name, :file_path, :file_format, :n_rows, :n_cols)
        ON CONFLICT(year, province, module, file_name) DO UPDATE SET
          file_path = excluded.file_path,
          file_format = excluded.file_format;
      ", params = as.list(row))
    }
    
    message("   Successfully indexed ", nrow(catalog_df), " file entries into survey_catalog.")
  }
}

# Summary
catalog_summary <- dbGetQuery(con, "
  SELECT year, province, file_format, COUNT(*) as file_count 
  FROM survey_catalog 
  GROUP BY year, province, file_format 
  ORDER BY year DESC, file_format
")

message("\n>> Survey Catalog Summary:")
print(catalog_summary)
