# R/cross_tab_template.R
# Reusable Cross-Tabulation Analysis Template for SUSENAS Workflows
# Strategy: Push 2-way aggregation to SQLite -> tidyverse for labeling & proportions -> publication ggplot2

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(forcats)
  library(scales)
})

# Sourcing utils safely (checking relative paths for Quarto)
utils_candidates <- c("R/utils.R", "utils.R", "../R/utils.R", "../../R/utils.R")
for (u in utils_candidates) {
  if (file.exists(u)) {
    source(u)
    break
  }
}

#' Generate Cross-Tabulation & Clustered/Stacked Bar Chart from SUSENAS SQLite Database
#'
#' @param var_row Primary categorical variable (x-axis / rows)
#' @param var_col Conditioning categorical variable (fill / legend / columns)
#' @param table Table or View name in SQLite (default: 'v_head_household_welfare_2023')
#' @param year Survey year (default: 2023)
#' @param weight_col Sampling weight column (default: 'PENIMBANG_RT'; set NULL for unweighted)
#' @param normalize Percent calculation basis: "row" (% within row_cat), "col" (% within col_cat), "total" (% of grand total), or "none" (absolute counts)
#' @param position Bar positioning: "dodge" (clustered), "stack" (stacked counts/pct), or "fill" (100% stacked)
#' @param filter_sql Optional SQL WHERE clause condition
#' @param title Custom plot title (optional)
#' @param subtitle Custom plot subtitle (default: "Provinsi Jawa Barat, {year}")
#' @param caption Custom plot caption (default: "Source: SUSENAS Jawa Barat {year}")
#' @param palette Color palette for col_cat fill
#' @param return_data Logical. If TRUE, returns list(plot = p, summary_table = tab, raw_data = df, sql = query). If FALSE, returns ggplot object.
#' @param db_path Path to SQLite susenas.db (optional, auto-resolved if NULL)
#' @return ggplot object or list with plot and data tables
analyze_crosstab <- function(var_row,
                             var_col,
                             table = "v_head_household_welfare_2023",
                             year = 2023,
                             weight_col = "PENIMBANG_RT",
                             normalize = c("row", "col", "total", "none"),
                             position = c("dodge", "stack", "fill"),
                             filter_sql = NULL,
                             title = NULL,
                             subtitle = NULL,
                             caption = NULL,
                             palette = NULL,
                             return_data = FALSE,
                             db_path = NULL) {
  normalize <- match.arg(normalize)
  position <- match.arg(position)

  # 1. Connect to Database
  con <- get_susenas_con(db_path)
  on.exit(dbDisconnect(con), add = TRUE)

  # 2. Heavy SQL Aggregation
  where_clauses <- c(
    sprintf("%s IS NOT NULL", var_row),
    sprintf("TRIM(CAST(%s AS TEXT)) != ''", var_row),
    sprintf("%s IS NOT NULL", var_col),
    sprintf("TRIM(CAST(%s AS TEXT)) != ''", var_col)
  )
  if (!is.null(filter_sql) && nzchar(filter_sql)) {
    where_clauses <- c(where_clauses, sprintf("(%s)", filter_sql))
  }
  where_stmt <- paste(where_clauses, collapse = " AND ")

  weight_expr <- if (!is.null(weight_col) && nzchar(weight_col)) {
    sprintf("SUM(COALESCE(%s, 1.0))", weight_col)
  } else {
    "COUNT(*)"
  }

  sql_query <- sprintf("
    SELECT 
      %s AS row_raw,
      %s AS col_raw,
      COUNT(*) AS sample_count,
      %s AS weighted_count
    FROM %s
    WHERE %s
    GROUP BY %s, %s
    ORDER BY %s, %s;
  ", var_row, var_col, weight_expr, table, where_stmt, var_row, var_col, var_row, var_col)

  raw_res <- dbGetQuery(con, sql_query)

  if (nrow(raw_res) == 0) {
    warning("Query returned 0 rows. Please verify variable names and filters.")
    return(NULL)
  }

  # 3. Tidyverse Post-Processing & Value Labeling
  clean_data <- raw_res %>%
    mutate(
      row_raw = as.character(row_raw),
      col_raw = as.character(col_raw),
      row_label = map_value_labels(var_row, row_raw, year = year),
      row_label = ifelse(is.na(row_label) | row_label == "", as.character(row_raw), row_label),
      col_label = map_value_labels(var_col, col_raw, year = year),
      col_label = ifelse(is.na(col_label) | col_label == "", as.character(col_raw), col_label)
    )

  # Proportions calculation based on normalization choice
  grand_total <- sum(clean_data$weighted_count, na.rm = TRUE)

  if (normalize == "row") {
    clean_data <- clean_data %>%
      group_by(row_label) %>%
      mutate(
        group_total = sum(weighted_count, na.rm = TRUE),
        pct = (weighted_count / group_total) * 100
      ) %>%
      ungroup()
    y_axis_label <- "Persentase dalam Baris (%)"
  } else if (normalize == "col") {
    clean_data <- clean_data %>%
      group_by(col_label) %>%
      mutate(
        group_total = sum(weighted_count, na.rm = TRUE),
        pct = (weighted_count / group_total) * 100
      ) %>%
      ungroup()
    y_axis_label <- "Persentase dalam Kolom (%)"
  } else if (normalize == "total") {
    clean_data <- clean_data %>%
      mutate(
        pct = (weighted_count / grand_total) * 100
      )
    y_axis_label <- "Persentase dari Total Populasi (%)"
  } else {
    clean_data <- clean_data %>%
      mutate(pct = weighted_count)
    y_axis_label <- if (!is.null(weight_col)) "Estimasi Populasi Terbobot" else "Jumlah Sampel"
  }

  clean_data <- clean_data %>%
    mutate(
      label_txt = if (normalize != "none") sprintf("%.1f%%", pct) else scales::comma(round(pct))
    )

  # Reshaped Cross-Tabulation Matrix
  crosstab_matrix <- clean_data %>%
    select(row_label, col_label, pct) %>%
    pivot_wider(names_from = col_label, values_from = pct, values_fill = 0)

  # Colors & Styling
  n_cats <- length(unique(clean_data$col_label))
  default_palette <- c("#2b5c8f", "#e6550d", "#2ca25f", "#756bb1", "#fa8c16", "#13c2c2", "#722ed1", "#eb2f96")
  active_palette <- if (!is.null(palette)) palette else default_palette[1:n_cats]

  plot_title <- if (!is.null(title)) title else paste("Tabulasi Silang:", var_row, "×", var_col)
  norm_str <- switch(normalize, "row" = "Normalisasi Baris", "col" = "Normalisasi Kolom", "total" = "Normalisasi Total", "Absolut")
  plot_subtitle <- if (!is.null(subtitle)) subtitle else sprintf("Provinsi Jawa Barat, %s (%s)", year, norm_str)
  plot_caption <- if (!is.null(caption)) caption else sprintf("Source: SUSENAS Jawa Barat %s", year)

  # 4. ggplot2 Publication-Ready Visualization
  pos_geom <- if (position == "dodge") {
    position_dodge(width = 0.8)
  } else if (position == "fill") {
    position_fill()
  } else {
    position_stack()
  }

  p <- ggplot(clean_data, aes(x = row_label, y = pct, fill = col_label)) +
    geom_col(position = pos_geom, width = 0.7) +
    scale_fill_manual(values = active_palette) +
    labs(
      title = plot_title,
      subtitle = plot_subtitle,
      x = NULL,
      y = y_axis_label,
      fill = var_col,
      caption = plot_caption
    ) +
    theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", size = 13, color = "#1a252c"),
      plot.subtitle = element_text(color = "#555555", margin = margin(b = 10)),
      plot.caption = element_text(face = "italic", color = "#666666", size = 9, margin = margin(t = 12)),
      legend.position = "top",
      legend.title = element_text(face = "bold", size = 10),
      panel.grid.minor = element_blank(),
      axis.text.x = element_text(face = "bold", color = "#2c3e50")
    )

  if (position == "dodge") {
    p <- p + geom_text(
      aes(label = label_txt),
      position = position_dodge(width = 0.8),
      vjust = -0.4,
      size = 3.2,
      fontface = "bold"
    ) +
    scale_y_continuous(
      labels = if (normalize != "none") function(x) paste0(x, "%") else scales::comma,
      expand = expansion(mult = c(0, 0.18))
    )
  }

  attr(p, "crosstab_matrix") <- crosstab_matrix
  attr(p, "data") <- clean_data
  attr(p, "sql") <- sql_query

  if (return_data) {
    return(list(plot = p, summary_table = crosstab_matrix, raw_data = clean_data, sql = sql_query))
  }

  p
}

# Standalone Execution Demonstration
if (sys.nframe() == 0L) {
  message(">> Running Cross-Tabulation Demo (KLASIFIKASI_PERKOTAAN_PERDESAAN x STATUS_KAWIN_KRT)...")
  demo_crosstab <- analyze_crosstab(
    var_row = "KLASIFIKASI_PERKOTAAN_PERDESAAN",
    var_col = "STATUS_KAWIN_KRT",
    normalize = "row",
    position = "dodge",
    title = "Status Perkawinan KRT Berdasarkan Klasifikasi Wilayah",
    subtitle = "Provinsi Jawa Barat, Susenas 2023 (% dalam kelompok wilayah)"
  )
  out_dir <- file.path("output", "figures")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_file <- file.path(out_dir, "demo_crosstab.png")
  ggsave(out_file, demo_crosstab, width = 9, height = 5.5, dpi = 300)
  message(sprintf(">> Demo cross-tabulation plot saved to %s", out_file))
}
