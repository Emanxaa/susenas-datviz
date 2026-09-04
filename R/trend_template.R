# R/trend_template.R
# Reusable Multi-Year Trend Analysis Template for SUSENAS Workflows
# Strategy: Push yearly aggregation to SQLite (UNION ALL) -> tidyverse for labeling -> publication ggplot2

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(ggplot2)
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

#' Generate Multi-Year Trend Line Chart from SUSENAS SQLite Database
#'
#' @param metric_col Numeric column name to track over time (e.g., 'PENGELUARAN_PERKAPITA', 'KALORI_PERKAPITA')
#' @param metric_func Aggregation metric: "mean" (weighted average), "sum", or "count" (default: "mean")
#' @param group_var Optional categorical variable for disaggregated lines (e.g., 'KLASIFIKASI_PERKOTAAN_PERDESAAN')
#' @param years Numeric vector of target survey years (default: 2019:2023)
#' @param table_prefix Table/View prefix pattern in SQLite (default: 'v_head_household_welfare')
#' @param weight_col Sampling weight column (default: 'PENIMBANG_RT'; set NULL for unweighted)
#' @param filter_sql Optional SQL WHERE condition applied across all years
#' @param title Custom plot title (optional)
#' @param subtitle Custom plot subtitle (optional)
#' @param caption Custom plot caption (optional)
#' @param palette Color palette vector
#' @param return_data Logical. If TRUE, returns list(plot = p, data = df, sql = query). If FALSE, returns ggplot object.
#' @param db_path Path to SQLite susenas.db (optional, auto-resolved if NULL)
#' @return ggplot object or list with plot and data
analyze_trend <- function(metric_col,
                          metric_func = c("mean", "sum", "count"),
                          group_var = NULL,
                          years = 2019:2023,
                          table_prefix = "v_head_household_welfare",
                          weight_col = "PENIMBANG_RT",
                          filter_sql = NULL,
                          title = NULL,
                          subtitle = NULL,
                          caption = NULL,
                          palette = NULL,
                          return_data = FALSE,
                          db_path = NULL) {
  metric_func <- match.arg(metric_func)

  # 1. Connect and detect available tables in SQLite
  con <- get_susenas_con(db_path)
  on.exit(dbDisconnect(con), add = TRUE)

  all_db_tables <- dbListTables(con)

  # Match tables for requested years
  year_queries <- list()
  valid_years <- c()

  for (yr in years) {
    # Check for direct year table (e.g., v_head_household_welfare_2023 or kor_rt_2023)
    tbl_candidate <- paste0(table_prefix, "_", yr)
    if (tbl_candidate %in% all_db_tables) {
      valid_years <- c(valid_years, yr)

      # Build WHERE clause
      where_clauses <- c(sprintf("%s IS NOT NULL", metric_col))
      if (!is.null(group_var)) {
        where_clauses <- c(where_clauses, sprintf("%s IS NOT NULL", group_var))
      }
      if (!is.null(filter_sql) && nzchar(filter_sql)) {
        where_clauses <- c(where_clauses, sprintf("(%s)", filter_sql))
      }
      where_stmt <- paste(where_clauses, collapse = " AND ")

      # Metric aggregation formula
      stat_expr <- if (metric_func == "mean") {
        if (!is.null(weight_col) && nzchar(weight_col)) {
          sprintf("SUM(CAST(%s AS REAL) * COALESCE(%s, 1.0)) / SUM(COALESCE(%s, 1.0))", metric_col, weight_col, weight_col)
        } else {
          sprintf("AVG(CAST(%s AS REAL))", metric_col)
        }
      } else if (metric_func == "sum") {
        if (!is.null(weight_col) && nzchar(weight_col)) {
          sprintf("SUM(CAST(%s AS REAL) * COALESCE(%s, 1.0))", metric_col, weight_col)
        } else {
          sprintf("SUM(CAST(%s AS REAL))", metric_col)
        }
      } else {
        "COUNT(*)"
      }

      if (!is.null(group_var)) {
        year_queries[[length(year_queries) + 1]] <- sprintf("
          SELECT 
            %d AS survey_year,
            CAST(%s AS TEXT) AS group_raw,
            %s AS metric_val,
            COUNT(*) AS sample_count
          FROM %s
          WHERE %s
          GROUP BY %s
        ", yr, group_var, stat_expr, tbl_candidate, where_stmt, group_var)
      } else {
        year_queries[[length(year_queries) + 1]] <- sprintf("
          SELECT 
            %d AS survey_year,
            'Semua' AS group_raw,
            %s AS metric_val,
            COUNT(*) AS sample_count
          FROM %s
          WHERE %s
        ", yr, stat_expr, tbl_candidate, where_stmt)
      }
    }
  }

  if (length(year_queries) == 0) {
    warning(sprintf("No tables matching prefix '%s' found in database for years: %s",
                    table_prefix, paste(years, collapse = ", ")))
    return(NULL)
  }

  union_sql <- paste(year_queries, collapse = "\nUNION ALL\n")
  union_sql <- paste0(union_sql, " ORDER BY survey_year ASC;")

  # Execute SQL
  raw_res <- dbGetQuery(con, union_sql)

  # 2. Tidyverse Post-Processing & Value Labeling
  clean_data <- raw_res %>%
    mutate(
      survey_year = as.integer(survey_year),
      group_label = if (!is.null(group_var)) {
        map_value_labels(group_var, group_raw, year = max(valid_years))
      } else {
        "Total Populasi"
      },
      group_label = ifelse(is.na(group_label) | group_label == "", group_raw, group_label)
    )

  # Formatting & Labels
  plot_title <- if (!is.null(title)) title else paste("Tren Perkembangan:", metric_col)
  year_range_str <- if (length(valid_years) == 1) as.character(valid_years[1]) else sprintf("%d–%d", min(valid_years), max(valid_years))
  plot_subtitle <- if (!is.null(subtitle)) subtitle else sprintf("Provinsi Jawa Barat, Periode %s (Statistik: %s)", year_range_str, toupper(metric_func))
  plot_caption <- if (!is.null(caption)) caption else sprintf("Source: SUSENAS Jawa Barat %s", year_range_str)

  # Colors
  n_groups <- length(unique(clean_data$group_label))
  default_palette <- c("#2b5c8f", "#d95f02", "#1b9e77", "#7570b3", "#e7298a", "#66a61e", "#e6ab02")
  active_palette <- if (!is.null(palette)) palette else default_palette[1:n_groups]

  # 3. ggplot2 Publication-Ready Visualization
  p <- ggplot(clean_data, aes(x = survey_year, y = metric_val, color = group_label, group = group_label)) +
    geom_line(linewidth = 1.15) +
    geom_point(size = 3.5, shape = 21, fill = "white", stroke = 1.8) +
    geom_text(
      aes(label = scales::comma(round(metric_val))),
      vjust = -1.2,
      size = 3.2,
      fontface = "bold",
      show.legend = FALSE
    ) +
    scale_x_continuous(
      breaks = valid_years,
      expand = expansion(mult = c(0.08, 0.08))
    ) +
    scale_y_continuous(
      labels = scales::comma,
      expand = expansion(mult = c(0.1, 0.2))
    ) +
    scale_color_manual(values = active_palette) +
    labs(
      title = plot_title,
      subtitle = plot_subtitle,
      x = "Tahun Survei",
      y = paste("Nilai", toupper(metric_func), metric_col),
      color = if (!is.null(group_var)) group_var else NULL,
      caption = plot_caption
    ) +
    theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", size = 13, color = "#1a252c"),
      plot.subtitle = element_text(color = "#555555", margin = margin(b = 10)),
      plot.caption = element_text(face = "italic", color = "#666666", size = 9, margin = margin(t = 12)),
      legend.position = if (!is.null(group_var)) "top" else "none",
      legend.title = element_text(face = "bold", size = 10),
      panel.grid.minor = element_blank(),
      axis.text.x = element_text(face = "bold", color = "#2c3e50")
    )

  attr(p, "data") <- clean_data
  attr(p, "sql") <- union_sql

  if (return_data) {
    return(list(plot = p, data = clean_data, sql = union_sql))
  }

  p
}

# Standalone Execution Demonstration
if (sys.nframe() == 0L) {
  message(">> Running Trend Template Demo (PENGELUARAN_PERKAPITA by KLASIFIKASI_PERKOTAAN_PERDESAAN)...")
  demo_trend <- analyze_trend(
    metric_col = "PENGELUARAN_PERKAPITA",
    metric_func = "mean",
    group_var = "KLASIFIKASI_PERKOTAAN_PERDESAAN",
    years = c(2023),
    title = "Rata-rata Pengeluaran Per Kapita Menurut Klasifikasi Wilayah",
    subtitle = "Provinsi Jawa Barat, Susenas 2023 (Rupiah/Bulan)"
  )
  out_dir <- file.path("output", "figures")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_file <- file.path(out_dir, "demo_trend.png")
  ggsave(out_file, demo_trend, width = 8, height = 5.5, dpi = 300)
  message(sprintf(">> Demo trend plot saved to %s", out_file))
}
