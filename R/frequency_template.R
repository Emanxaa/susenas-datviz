# R/frequency_template.R
# Reusable Frequency Analysis Template for SUSENAS Workflows
# Strategy: Push aggregation & filtering to SQLite -> tidyverse for labeling -> publication ggplot2

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
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

#' Generate Frequency Analysis & Bar Chart from SUSENAS SQLite Database
#'
#' @param var Column name of the categorical variable to analyze (e.g., 'PENDIDIKAN_TERTINGGI_KRT', 'R105')
#' @param table Table or View name in SQLite (default: 'v_head_household_welfare_2023')
#' @param year Survey year (default: 2023)
#' @param weight_col Sampling weight column (default: 'PENIMBANG_RT'; set NULL for unweighted)
#' @param top_n Maximum number of categories to display (default: 15)
#' @param filter_sql Optional SQL WHERE clause condition (e.g., "UMUR_KRT >= 25")
#' @param title Custom plot title (optional)
#' @param subtitle Custom plot subtitle (default: "Provinsi Jawa Barat, {year}")
#' @param caption Custom plot caption (default: "Source: SUSENAS Jawa Barat {year}")
#' @param fill_color Hex color for bar fill (default: "#2b5c8f")
#' @param return_data Logical. If TRUE, returns list(plot = p, data = df, sql = query). If FALSE, returns ggplot object.
#' @param db_path Path to SQLite susenas.db (optional, auto-resolved if NULL)
#' @return ggplot object or list with plot and data
analyze_frequency <- function(var,
                              table = "v_head_household_welfare_2023",
                              year = 2023,
                              weight_col = "PENIMBANG_RT",
                              top_n = 15,
                              filter_sql = NULL,
                              title = NULL,
                              subtitle = NULL,
                              caption = NULL,
                              fill_color = "#2b5c8f",
                              return_data = FALSE,
                              db_path = NULL) {
  # 1. Resolve database connection
  con <- get_susenas_con(db_path)
  on.exit(dbDisconnect(con), add = TRUE)

  # 2. Construct SQL Query (Heavy aggregation executed in SQLite)
  where_clauses <- c(sprintf("%s IS NOT NULL", var), sprintf("TRIM(CAST(%s AS TEXT)) != ''", var))
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
      %s AS category_raw,
      COUNT(*) AS sample_count,
      %s AS weighted_count
    FROM %s
    WHERE %s
    GROUP BY %s
    ORDER BY weighted_count DESC;
  ", var, weight_expr, table, where_stmt, var)

  # Execute SQL
  raw_res <- dbGetQuery(con, sql_query)

  if (nrow(raw_res) == 0) {
    warning("Query returned 0 rows. Please verify parameters and filter criteria.")
    return(NULL)
  }

  # 3. Tidyverse Post-Processing (Labeling, Proportions, Factor Reordering)
  clean_data <- raw_res %>%
    mutate(
      category_raw = as.character(category_raw),
      category_label = map_value_labels(var, category_raw, year = year),
      category_label = ifelse(is.na(category_label) | category_label == "", as.character(category_raw), category_label)
    )

  # Apply top_n collapsing if cardinality exceeds threshold
  if (nrow(clean_data) > top_n) {
    top_records <- clean_data %>% slice_head(n = top_n - 1)
    other_records <- clean_data %>%
      slice(top_n:n()) %>%
      summarise(
        category_raw = "Lainnya",
        sample_count = sum(sample_count, na.rm = TRUE),
        weighted_count = sum(weighted_count, na.rm = TRUE),
        category_label = "Lainnya"
      )
    clean_data <- bind_rows(top_records, other_records)
  }

  total_weighted <- sum(clean_data$weighted_count, na.rm = TRUE)
  clean_data <- clean_data %>%
    mutate(
      pct = (weighted_count / total_weighted) * 100,
      label_formatted = sprintf("%s (%0.1f%%)", scales::comma(round(weighted_count)), pct),
      category_label = fct_reorder(category_label, weighted_count)
    )

  # 4. Publication-Ready ggplot2 Output
  plot_title <- if (!is.null(title)) title else paste("Distribusi Frekuensi:", var)
  plot_subtitle <- if (!is.null(subtitle)) subtitle else sprintf("Provinsi Jawa Barat, %s%s", year, ifelse(!is.null(weight_col), " (Terbobot)", " (Sampel)"))
  plot_caption <- if (!is.null(caption)) caption else sprintf("Source: SUSENAS Jawa Barat %s", year)

  p <- ggplot(clean_data, aes(x = category_label, y = weighted_count)) +
    geom_col(fill = fill_color, width = 0.68) +
    geom_text(aes(label = label_formatted), hjust = -0.05, size = 3.3, color = "#222222") +
    scale_y_continuous(
      labels = scales::comma,
      expand = expansion(mult = c(0, 0.22))
    ) +
    coord_flip() +
    labs(
      title = plot_title,
      subtitle = plot_subtitle,
      x = NULL,
      y = if (!is.null(weight_col)) "Estimasi Populasi Terbobot (Individu / RT)" else "Jumlah Sampel",
      caption = plot_caption
    ) +
    theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", size = 13, color = "#1a252c"),
      plot.subtitle = element_text(color = "#555555", margin = margin(b = 10)),
      plot.caption = element_text(face = "italic", color = "#666666", size = 9, margin = margin(t = 12)),
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank(),
      axis.text.y = element_text(face = "bold", color = "#2c3e50")
    )

  # Store summary data as an attribute
  attr(p, "data") <- clean_data
  attr(p, "sql") <- sql_query

  if (return_data) {
    return(list(plot = p, data = clean_data, sql = sql_query))
  }

  p
}

# Standalone Execution Demonstration
if (sys.nframe() == 0L) {
  message(">> Running Frequency Template Demo (PENDIDIKAN_TERTINGGI_KRT)...")
  demo_plot <- analyze_frequency(
    var = "PENDIDIKAN_TERTINGGI_KRT",
    table = "v_head_household_welfare_2023",
    year = 2023,
    title = "Distribusi Pendidikan Tertinggi Kepala Rumah Tangga",
    subtitle = "Provinsi Jawa Barat, Susenas 2023"
  )
  out_dir <- file.path("output", "figures")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_file <- file.path(out_dir, "demo_frequency.png")
  ggsave(out_file, demo_plot, width = 9, height = 6, dpi = 300)
  message(sprintf(">> Demo plot saved to %s", out_file))
}
