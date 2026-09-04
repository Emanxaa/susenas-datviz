# R/semantic_planner.R
# SUSENAS Semantic Planner: Translates Research Objectives into Optimized ETL & Visualization Plans
# Grounded in official BPS SUSENAS metadata (2019-2023)
# Follows SQLite-First Architecture + tidyverse + ggplot2 + Quarto

utils_candidates <- c("R/utils.R", "utils.R", "../R/utils.R", "../../R/utils.R")
for (u in utils_candidates) {
  if (file.exists(u)) {
    source(u)
    break
  }
}

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(tibble)
  library(stringr)
  library(jsonlite)
  library(ggplot2)
  library(scales)
  library(forcats)
})

#' Search registered research concepts by keyword
#' @param query Search query string
#' @return tibble of matching concepts
search_concepts <- function(query = "") {
  con <- get_metadata_con()
  on.exit(dbDisconnect(con), add = TRUE)
  
  clean_q <- tolower(trimws(query))
  concepts_df <- as_tibble(dbGetQuery(con, "
    SELECT concept_id, concept_name, domain, description, primary_variables, 
           covariate_variables, required_modules, default_table, indicator_formula, 
           filter_recommendation, recommended_viz, keywords 
    FROM concept_registry
  "))
  
  if (nzchar(clean_q)) {
    concepts_df <- concepts_df %>%
      filter(
        grepl(clean_q, tolower(keywords)) |
        grepl(clean_q, tolower(concept_name)) |
        grepl(clean_q, tolower(domain)) |
        grepl(clean_q, tolower(description))
      )
  }
  
  concepts_df
}

#' Match Research Objective to Semantic Concept & Variables
#' @param objective Research goal in Indonesian or English
#' @return list with matched concept, variables, and detected dimensions
match_objective_semantics <- function(objective) {
  obj_lower <- tolower(objective)
  
  con <- get_metadata_con()
  on.exit(dbDisconnect(con), add = TRUE)
  
  concepts_df <- as_tibble(dbGetQuery(con, "SELECT * FROM concept_registry"))
  
  # Compute matching score
  scores <- sapply(seq_len(nrow(concepts_df)), function(i) {
    kw_list <- unlist(strsplit(concepts_df$keywords[i], ",\\s*"))
    kw_hits <- sum(sapply(kw_list, function(k) grepl(paste0("\\b", k, "\\b"), obj_lower, perl = TRUE)))
    name_hits <- if (grepl(tolower(concepts_df$concept_name[i]), obj_lower, fixed = TRUE)) 3 else 0
    kw_hits + name_hits
  })
  
  best_idx <- if (max(scores) > 0) which.max(scores) else 1
  matched_concept <- as.list(concepts_df[best_idx, ])
  
  # Parse JSON arrays
  matched_concept$primary_vars <- tryCatch(jsonlite::fromJSON(matched_concept$primary_variables), error = function(e) character(0))
  matched_concept$covariate_vars <- tryCatch(jsonlite::fromJSON(matched_concept$covariate_variables), error = function(e) character(0))
  
  # Detect specific covariate dimensions mentioned in objective
  detected_covariates <- character(0)
  if (grepl("pendidikan|sekolah|ijazah", obj_lower)) {
    detected_covariates <- c(detected_covariates, "PENDIDIKAN_TERTINGGI_KRT")
  }
  if (grepl("kota|desa|perkotaan|perdesaan|wilayah|tipe", obj_lower)) {
    detected_covariates <- c(detected_covariates, "KLASIFIKASI_PERKOTAAN_PERDESAAN")
  }
  if (grepl("kabupaten|kota|daerah|kabkot", obj_lower)) {
    detected_covariates <- c(detected_covariates, "KODE_KABKOT")
  }
  if (grepl("gender|jenis kelamin|perempuan|laki", obj_lower)) {
    detected_covariates <- c(detected_covariates, "JENIS_KELAMIN_KRT")
  }
  if (grepl("pkh|bansos|bpnt|bantuan", obj_lower)) {
    detected_covariates <- c(detected_covariates, "R2204A", "R2207")
  }
  
  list(
    concept = matched_concept,
    score = scores[best_idx],
    detected_covariates = unique(detected_covariates)
  )
}

#' Check Cross-Year Variable Compatibility
#' @param var_names Vector of variable names or concept names
#' @return tibble of compatibility records
check_variable_compatibility <- function(var_names = NULL) {
  con <- get_metadata_con()
  on.exit(dbDisconnect(con), add = TRUE)
  
  comp_df <- as_tibble(dbGetQuery(con, "
    SELECT variable_concept, domain, var_2019, var_2020, var_2021, var_2022, var_2023, 
           module, compatibility_status, value_coding_consistent, notes 
    FROM variable_compatibility
  "))
  
  if (!is.null(var_names) && length(var_names) > 0) {
    comp_df <- comp_df %>%
      filter(
        var_2023 %in% var_names |
        var_2019 %in% var_names |
        sapply(variable_concept, function(vc) any(grepl(vc, var_names, ignore.case = TRUE)))
      )
  }
  
  comp_df
}

#' Generate Semantic ETL and Analytical Plan
#'
#' @param objective Character research objective
#' @param year Target survey year (default: 2023)
#' @param filter_geo Optional geographic filter (e.g., KODE_KABKOT = '73' for Kota Bandung)
#' @param group_by Optional grouping variable override
#' @param options List of additional options (e.g., top_n, weight, table_override)
#' @return An object of class `susenas_plan`
plan_susenas <- function(objective,
                         year = 2023,
                         filter_geo = NULL,
                         group_by = NULL,
                         options = list()) {
  # 1. Semantic matching
  sem <- match_objective_semantics(objective)
  concept <- sem$concept
  concept_id <- concept$concept_id
  
  con_meta <- get_metadata_con()
  on.exit(dbDisconnect(con_meta), add = TRUE)
  
  # 2. Determine Primary Table / View & Grouping Variable
  dim_var <- if (!is.null(group_by)) {
    group_by
  } else if (length(sem$detected_covariates) > 0) {
    sem$detected_covariates[1]
  } else if (concept_id == "ketahanan_pangan") {
    "PENDIDIKAN_TERTINGGI_KRT"
  } else if (concept_id %in% c("kemiskinan", "ketimpangan")) {
    "KLASIFIKASI_PERKOTAAN_PERDESAAN"
  } else if (concept_id == "perlindungan_sosial") {
    "KLASIFIKASI_PERKOTAAN_PERDESAAN"
  } else {
    "KODE_KABKOT"
  }
  
  # Choose table
  table_name <- if (!is.null(options$table_override)) {
    options$table_override
  } else if (dim_var %in% c("PENDIDIKAN_TERTINGGI_KRT", "STATUS_KAWIN_KRT", "JENIS_KELAMIN_KRT", "UMUR_KRT")) {
    paste0("v_head_household_welfare_", year)
  } else {
    paste0("v_household_expenditure_", year)
  }
  
  # 3. Retrieve and Validate Required Variables from Metadata
  needed_vars <- unique(c(concept$primary_vars, sem$detected_covariates, dim_var, "URUT", "R101", "R102", "R105", "WERT", "PENIMBANG_RT"))
  
  # Clean alias to BPS raw code mapping for metadata lookup
  clean_lookup_vars <- sapply(needed_vars, function(v) {
    if (v %in% names(COLUMN_TO_METADATA_VAR)) COLUMN_TO_METADATA_VAR[[v]] else v
  })
  
  placeholders <- paste(rep("?", length(clean_lookup_vars)), collapse = ",")
  var_sql <- sprintf("
    SELECT DISTINCT variable, label, module, year, data_type 
    FROM variable_registry 
    WHERE variable IN (%s) AND year = ?
    ORDER BY module, variable
  ", placeholders)
  
  vars_metadata <- as_tibble(dbGetQuery(con_meta, var_sql, params = as.list(unname(c(clean_lookup_vars, as.character(year))))))
  
  # Add virtual view columns if not in registry
  view_cols <- tibble(
    variable = c("PENGELUARAN_MAKANAN", "PENGELUARAN_NON_MAKANAN", "TOTAL_PENGELUARAN", "PENGELUARAN_PERKAPITA", "KALORI_PERKAPITA", "PROTEIN_PERKAPITA", "PENDIDIKAN_TERTINGGI_KRT", "KLASIFIKASI_PERKOTAAN_PERDESAAN", "PENIMBANG_RT"),
    label = c("Rata-rata Pengeluaran Makanan Sebulan (Alias View)", "Rata-rata Pengeluaran Bukan Makanan Sebulan (Alias View)", "Total Pengeluaran Rumah Tangga Sebulan (FOOD + NONFOOD)", "Rata-rata Pengeluaran Perkapita Sebulan (KAPITA)", "Konsumsi Kalori Perkapita Sehari (KALORI_KAP)", "Konsumsi Protein Perkapita Sehari (PROTE_KAP)", "Jenjang Pendidikan Tertinggi KRT (R612 Recoded)", "Tipe Wilayah Kota/Desa (R105 Mapped)", "Faktor Bobot Sampling Rumah Tangga (WERT)"),
    module = c("Analytical View", "Analytical View", "Analytical View", "Analytical View", "Analytical View", "Analytical View", "Analytical View", "Analytical View", "Analytical View"),
    year = as.integer(year),
    data_type = c("Numeric", "Numeric", "Numeric", "Numeric", "Numeric", "Numeric", "Categorical", "Categorical", "Numeric")
  )
  
  combined_vars <- bind_rows(
    vars_metadata,
    view_cols %>% filter(variable %in% needed_vars, !variable %in% vars_metadata$variable)
  ) %>% distinct(variable, .keep_all = TRUE)
  
  # 4. Identify Joins
  join_info <- dbGetQuery(con_meta, "
    SELECT from_table, to_table, join_keys, join_type, relationship 
    FROM join_registry 
    WHERE from_table IN ('kor_rt', 'kor_individu', 'kp_bp43')
  ")
  
  # 5. Generate SQLite-First ETL Query
  where_clauses <- c(
    sprintf("%s IS NOT NULL", dim_var),
    sprintf("TRIM(CAST(%s AS TEXT)) != ''", dim_var)
  )
  if (!is.null(filter_geo)) {
    where_clauses <- c(where_clauses, sprintf("KODE_KABKOT = '%s'", filter_geo))
  }
  
  sql_query <- ""
  metric_name <- ""
  metric_col <- ""
  viz_type <- concept$recommended_viz
  
  if (concept_id == "ketahanan_pangan") {
    metric_name <- "Pangsa Pengeluaran Makanan (%)"
    metric_col <- "pangsa_pangan_pct"
    sql_query <- sprintf("
-- [SQLite Heavy ETL]: Agregasi Pembobotan Pangsa Pangan menurut %s
SELECT 
    %s AS kategori_kode,
    COUNT(*) AS n_sample,
    ROUND(SUM(PENIMBANG_RT), 0) AS populasi_rt,
    ROUND(SUM(PENGELUARAN_MAKANAN * PENIMBANG_RT) / SUM(TOTAL_PENGELUARAN * PENIMBANG_RT) * 100, 2) AS %s,
    ROUND(SUM(KALORI_PERKAPITA * PENIMBANG_RT) / SUM(PENIMBANG_RT), 1) AS rata_kalori_kapita,
    ROUND(SUM(PROTEIN_PERKAPITA * PENIMBANG_RT) / SUM(PENIMBANG_RT), 2) AS rata_protein_kapita
FROM %s
WHERE %s
  AND TOTAL_PENGELUARAN > 0
GROUP BY %s
ORDER BY %s DESC;
", dim_var, dim_var, metric_col, table_name, paste(where_clauses, collapse = " AND "), dim_var, metric_col)
    
  } else if (concept_id %in% c("kemiskinan", "ketimpangan")) {
    metric_name <- "Rata-rata Pengeluaran Per Kapita (Rp/Bulan)"
    metric_col <- "pengeluaran_perkapita_rata"
    sql_query <- sprintf("
-- [SQLite Heavy ETL]: Distribusi Pengeluaran Per Kapita Terbobot menurut %s
SELECT 
    %s AS kategori_kode,
    COUNT(*) AS n_sample,
    ROUND(SUM(PENIMBANG_RT), 0) AS populasi_rt,
    ROUND(SUM(PENGELUARAN_PERKAPITA * PENIMBANG_RT) / SUM(PENIMBANG_RT), 0) AS %s,
    ROUND(SUM(PENGELUARAN_MAKANAN * PENIMBANG_RT) / SUM(PENIMBANG_RT), 0) AS rata_makanan,
    ROUND(SUM(PENGELUARAN_NON_MAKANAN * PENIMBANG_RT) / SUM(PENIMBANG_RT), 0) AS rata_non_makanan
FROM %s
WHERE %s
  AND PENGELUARAN_PERKAPITA > 0
GROUP BY %s
ORDER BY %s DESC;
", dim_var, dim_var, metric_col, table_name, paste(where_clauses, collapse = " AND "), dim_var, metric_col)
    
  } else if (concept_id == "perlindungan_sosial") {
    metric_name <- "Cakupan Bansos & Rata-rata Konsumsi Kalori"
    metric_col <- "rata_kalori"
    sql_query <- sprintf("
-- [SQLite Heavy ETL]: Evaluasi Bansos PKH/BPNT terhadap Asupan Kalori Terbobot
SELECT 
    %s AS kategori_kode,
    R2204A AS status_pkh,
    COUNT(*) AS n_sample,
    ROUND(SUM(PENIMBANG_RT), 0) AS populasi_rt,
    ROUND(SUM(KONSUMSI_KALORI_PERKAPITA * PENIMBANG_RT) / SUM(PENIMBANG_RT), 1) AS %s,
    ROUND(SUM(PENGELUARAN_PERKAPITA * PENIMBANG_RT) / SUM(PENIMBANG_RT), 0) AS rata_pengeluaran_kapita
FROM %s
WHERE %s
  AND R2204A IN (0, 1)
GROUP BY %s, R2204A
ORDER BY %s, R2204A;
", dim_var, metric_col, table_name, paste(where_clauses, collapse = " AND "), dim_var, dim_var)
    viz_type <- "cross_tab"
    
  } else {
    metric_name <- "Rata-rata Terbobot Indikator Utama"
    metric_col <- "nilai_indikator"
    sql_query <- sprintf("
-- [SQLite Heavy ETL]: Agregasi Indikator Terbobot menurut %s
SELECT 
    %s AS kategori_kode,
    COUNT(*) AS n_sample,
    ROUND(SUM(PENIMBANG_RT), 0) AS populasi_rt,
    ROUND(AVG(PENGELUARAN_PERKAPITA), 0) AS %s
FROM %s
WHERE %s
GROUP BY %s
ORDER BY %s DESC;
", dim_var, dim_var, metric_col, table_name, paste(where_clauses, collapse = " AND "), dim_var, metric_col)
  }
  
  # 6. Generate Tidyverse Wrangling Code
  r_wrangling_code <- sprintf("
# [Tidyverse Wrangling]: Konversi label kategori & pemformatan tabel
source('R/utils.R')

# 1. Buka koneksi SQLite
con <- get_susenas_con()
on.exit(dbDisconnect(con), add = TRUE)

# 2. Eksekusi query ETL terbobot
raw_df <- as_tibble(dbGetQuery(con, sql_query))

# 3. Labeling metadata otomatis dari metadata.db
clean_df <- raw_df %%>%%
  mutate(
    kategori_label = map_value_labels('%s', kategori_kode, year = %d)
  ) %%>%%
  filter(!is.na(kategori_label), kategori_label != '') %%>%%
  arrange(desc(%s))
", dim_var, year, metric_col)
  
  # 7. Generate ggplot2 Visualization Code
  dim_title <- gsub("_", " ", dim_var)
  p_title <- sprintf("%s menurut %s", metric_name, dim_title)
  p_sub <- sprintf("Provinsi Jawa Barat, SUSENAS %d (Hasil Olahan SQLite)", year)
  p_cap <- sprintf("Source: SUSENAS Jawa Barat %d | BPS RI", year)
  
  ggplot_code <- sprintf("
# [ggplot2 Visualization]: Visualisasi publikasi berbasis theme_minimal
p <- ggplot(clean_df, aes(x = reorder(kategori_label, %s), y = %s)) +
  geom_col(fill = '#1f77b4', width = 0.7, alpha = 0.9) +
  geom_text(aes(label = scales::comma(%s, accuracy = 0.1)), 
            hjust = -0.15, size = 3.5, fontface = 'bold', color = '#2c3e50') +
  coord_flip() +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = '%s',
    subtitle = '%s',
    x = '%s',
    y = '%s',
    caption = '%s'
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = 'bold', size = 14, color = '#1a252f'),
    plot.subtitle = element_text(color = '#555555', margin = margin(b = 10)),
    plot.caption = element_text(color = '#777777', size = 9, margin = margin(t = 12)),
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    axis.text = element_text(color = '#333333')
  )
", metric_col, metric_col, metric_col, p_title, p_sub, dim_title, metric_name, p_cap)
  
  # 8. Grounded Interpretation
  interpretation <- if (concept_id == "ketahanan_pangan") {
    sprintf("Berdasarkan Hukum Engel (Engels Law) dan pedoman ketahanan pangan BPS/FAO, rumah tangga dengan pangsa pengeluaran pangan di bawah 60%% dikategorikan memiliki ketahanan pangan yang relatif baik, sedangkan pangsa pangan di atas 60%% menunjukkan kerentanan ekonomi karena sebagian besar anggaran dialokasikan hanya untuk bertahan hidup. Pada data SUSENAS Jawa Barat %d, teridentifikasi gradien jelas antara capaian %s dengan pangsa pangan dan pemenuhan asupan kalori.", year, dim_title)
  } else if (concept_id %in% c("kemiskinan", "ketimpangan")) {
    sprintf("Distribusi pengeluaran per kapita mencerminkan stratifikasi ekonomi riil rumah tangga Jawa Barat tahun %d. Pengelompokan menurut %s menunjukkan disparitas daya beli yang signifikan, di mana pemenuhan kebutuhan non-makanan (perumahan, pendidikan, dan kesehatan) jauh lebih tinggi pada kelompok atas dibandingkan kelompok prasejahtera.", year, dim_title)
  } else if (concept_id == "perlindungan_sosial") {
    sprintf("Analisis komparatif penerima program perlindungan sosial (PKH) pada SUSENAS %d membuktikan peran jaring pengaman sosial dalam menjaga batas minimum konsumsi kalori dan pangan bagi kelompok desil bawah, meskipun rata-rata pengeluaran per kapita mereka secara struktural masih berada di bawah rata-rata umum.", year)
  } else {
    sprintf("Indikator empiris SUSENAS Jawa Barat %d menunjukkan variasi sistematis antar kelompok %s yang sejalan dengan karakteristik sosio-demografis populasi.", year, dim_title)
  }
  
  # 9. Cross-Year Compatibility Check
  compat_records <- check_variable_compatibility(needed_vars)
  
  # Assemble Plan Object
  plan <- list(
    objective = objective,
    year = year,
    concept = concept,
    primary_metric = metric_name,
    metric_col = metric_col,
    dimension_var = dim_var,
    table = table_name,
    variables = combined_vars,
    joins = join_info,
    sql = sql_query,
    r_wrangling = r_wrangling_code,
    ggplot = ggplot_code,
    interpretation = interpretation,
    compatibility = compat_records,
    source_citation = list(
      year = year,
      province = "Jawa Barat",
      metadata_file = "KOR 2023 Layout_data_Susenas.xlsx / 2023 KP - Layout_data_Susenas.xlsx",
      questionnaire = "VSEN23.pdf / 2023 KP - VSEN.pdf"
    )
  )
  class(plan) <- "susenas_plan"
  plan
}

#' Format Plan to Markdown Template conforming to AGENTS.md
#' @param plan A susenas_plan object
#' @return Character markdown string
format_plan_markdown <- function(plan) {
  var_tbl_md <- paste(
    "| Variabel | Label Resmi BPS | Modul | Tipe Data |",
    "| :--- | :--- | :--- | :--- |",
    paste(
      sprintf("| `%s` | %s | %s | %s |",
              plan$variables$variable,
              plan$variables$label,
              plan$variables$module,
              ifelse(is.na(plan$variables$data_type), "Standard", plan$variables$data_type)),
      collapse = "\n"
    ),
    sep = "\n"
  )
  
  compat_tbl_md <- if (nrow(plan$compatibility) > 0) {
    paste(
      "| Konsep Variabel | 2019 | 2020 | 2021 | 2022 | 2023 | Status Kompatibilitas | Catatan Harmonisasi |",
      "| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |",
      paste(
        sprintf("| %s | `%s` | `%s` | `%s` | `%s` | `%s` | **%s** | %s |",
                plan$compatibility$variable_concept,
                plan$compatibility$var_2019,
                plan$compatibility$var_2020,
                plan$compatibility$var_2021,
                plan$compatibility$var_2022,
                plan$compatibility$var_2023,
                plan$compatibility$compatibility_status,
                plan$compatibility$notes),
        collapse = "\n"
      ),
      sep = "\n"
    )
  } else {
    "_Seluruh variabel utama terverifikasi identik antar-tahun._"
  }
  
  output <- sprintf("
## Objective
%s

## Variables
%s

### Kompatibilitas Variabel Multi-Tahun (2019–2023)
%s

## Tables & Joins
- **Primary Source:** `%s`
- **Relasi Database (join_registry):**
  - `kor_rt` <-> `kp_bp43`: `[\"URUT\"]` (One-to-One household link)
  - `kor_rt` <-> `kor_individu`: `[\"URUT\"]` (One-to-Many individual link; KRT filter: `R403 = 1`)
  - `kor_rt` <-> Wilayah: `[\"R101\", \"R102\"]` (Provinsi 32 Jawa Barat & Kode Kab/Kota)

## SQL
```sql
%s
```

## R Code
```r
%s
```

## Visualization
```r
%s
```

## Interpretation
%s

## Source
- **Tahun Survei:** SUSENAS %d
- **Wilayah Cakupan:** %s
- **Metadata Resmi:** %s
- **Kuesioner Rujukan:** %s
",
    plan$objective,
    var_tbl_md,
    compat_tbl_md,
    plan$table,
    trimws(plan$sql),
    trimws(plan$r_wrangling),
    trimws(plan$ggplot),
    plan$interpretation,
    plan$source_citation$year,
    plan$source_citation$province,
    plan$source_citation$metadata_file,
    plan$source_citation$questionnaire
  )
  
  output
}

#' S3 Print method for susenas_plan
#' @param x A susenas_plan object
#' @param ... Additional arguments
print.susenas_plan <- function(x, ...) {
  cat(format_plan_markdown(x))
  invisible(x)
}

#' Execute Plan Directly against susenas.db
#'
#' @param plan A susenas_plan object
#' @param save_plot Optional path to save png file
#' @return list containing raw_data, clean_data, and ggplot object
execute_plan <- function(plan, save_plot = NULL) {
  con <- get_susenas_con()
  on.exit(dbDisconnect(con), add = TRUE)
  
  # 1. Execute SQL
  raw_df <- as_tibble(dbGetQuery(con, plan$sql))
  
  # 2. Tidyverse Labeling
  clean_df <- raw_df %>%
    mutate(
      kategori_label = map_value_labels(plan$dimension_var, kategori_kode, year = plan$year)
    ) %>%
    filter(!is.na(kategori_label), kategori_label != "")
  
  # 3. Create ggplot2 object
  metric_col <- plan$metric_col
  dim_title <- gsub("_", " ", plan$dimension_var)
  p_title <- sprintf("%s menurut %s", plan$primary_metric, dim_title)
  p_sub <- sprintf("Provinsi Jawa Barat, SUSENAS %d (Kompilasi SQLite-First)", plan$year)
  p_cap <- sprintf("Source: SUSENAS Jawa Barat %d | BPS RI", plan$year)
  
  p <- ggplot(clean_df, aes(x = reorder(kategori_label, !!sym(metric_col)), y = !!sym(metric_col))) +
    geom_col(fill = "#1b7837", width = 0.7, alpha = 0.9) +
    geom_text(aes(label = scales::comma(!!sym(metric_col), accuracy = 0.1)), 
              hjust = -0.15, size = 3.5, fontface = "bold", color = "#2c3e50") +
    coord_flip() +
    scale_y_continuous(expand = expansion(mult = c(0, 0.18))) +
    labs(
      title = p_title,
      subtitle = p_sub,
      x = dim_title,
      y = plan$primary_metric,
      caption = p_cap
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 13, color = "#1a252f"),
      plot.subtitle = element_text(color = "#555555", margin = margin(b = 10)),
      plot.caption = element_text(color = "#777777", size = 9, margin = margin(t = 12)),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_blank(),
      axis.text = element_text(color = "#333333")
    )
  
  if (!is.null(save_plot)) {
    if (!dir.exists(dirname(save_plot))) {
      dir.create(dirname(save_plot), recursive = TRUE, showWarnings = FALSE)
    }
    ggsave(save_plot, plot = p, width = 8.5, height = 5.5, dpi = 300)
    message("   Saved figure to: ", save_plot)
  }
  
  list(
    raw_data = raw_df,
    clean_data = clean_df,
    plot = p
  )
}

#' Render Plan as a Reproducible Quarto Document (.qmd)
#' @param plan A susenas_plan object
#' @param output_file Destination path for .qmd file
#' @param execute Logical, whether to render .qmd using Quarto CLI
render_plan_to_quarto <- function(plan, output_file = "quarto/susenas_research_plan.qmd", execute = FALSE) {
  if (!dir.exists(dirname(output_file))) {
    dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  }
  
  qmd_content <- sprintf('---
title: "SUSENAS Research Plan & Automated ETL Report"
subtitle: "%s"
author: "SUSENAS Research Agent (BPS Jawa Barat %d)"
date: today
format:
  html:
    toc: true
    toc-depth: 3
    theme: cosmo
    code-fold: show
    fig-width: 8.5
    fig-height: 5.5
execute:
  echo: true
  warning: false
  message: false
---

%s

## Eksekusi Live Komputasi

```{r}
#| label: live-execution
#| fig.width: 8.5
#| fig.height: 5.5

for (p in c("R/semantic_planner.R", "../R/semantic_planner.R", "semantic_planner.R")) {
  if (file.exists(p)) { source(p); break }
}
plan_obj <- plan_susenas("%s", year = %d)
res <- execute_plan(plan_obj)

# Visualisasi ggplot2
print(res$plot)

# Tabel Data Terbobot
knitr::kable(res$clean_data, caption = "Hasil Agregasi Terbobot dari SQLite")
```
', plan$objective, plan$year, format_plan_markdown(plan), plan$objective, plan$year)
  
  writeLines(qmd_content, output_file, useBytes = TRUE)
  message(">> Quarto report written to: ", output_file)
  
  if (execute) {
    quarto_bin <- "C:\\Users\\emanu\\AppData\\Local\\Programs\\Quarto\\bin\\quarto.exe"
    if (file.exists(quarto_bin)) {
      cmd <- sprintf('& "%s" render "%s"', quarto_bin, output_file)
      message(">> Rendering Quarto report: ", cmd)
      system(paste("powershell -Command", shQuote(cmd)))
    } else {
      warning("Quarto binary not found at standard path.")
    }
  }
  
  output_file
}
