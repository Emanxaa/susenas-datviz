# R/barplot_template.R
# Reusable Bar Plot Analysis Template for SUSENAS Workflows
# Strategy: Push weighted metric calculation to SQLite -> tidyverse for labeling -> publication ggplot2

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

#' Generate Ranked Bar Chart from SUSENAS SQLite Database
#'
#' @param cat_var Categorical variable for groups/bars (e.g., 'KODE_KABKOT', 'PENDIDIKAN_TERTINGGI_KRT')
#' @param num_var Numeric variable to aggregate (e.g., 'PENGELUARAN_PERKAPITA', 'KALORI_PERKAPITA')
#' @param stat Aggregation statistic: "mean" (weighted average) or "sum" (default: "mean")
#' @param table Table or View name in SQLite (default: 'v_head_household_welfare_2023')
#' @param year Survey year (default: 2023)
#' @param weight_col Sampling weight column (default: 'PENIMBANG_RT'; set NULL for unweighted)
#' @param top_n Maximum number of categories to show (default: 15)
#' @param horizontal Logical. If TRUE, creates horizontal ranking chart (default: TRUE)
#' @param filter_sql Optional SQL WHERE clause condition
#' @param title Custom plot title (optional)
#' @param subtitle Custom plot subtitle (default: "Provinsi Jawa Barat, {year}")
#' @param caption Custom plot caption (default: "Source: SUSENAS Jawa Barat {year}")
#' @param fill_color Bar fill hex color (default: "#1b7837")
#' @param return_data Logical. If TRUE, returns list(plot = p, data = df, sql = query). If FALSE, returns ggplot object.
#' @param db_path Path to SQLite susenas.db (optional, auto-resolved if NULL)
#' @return ggplot object or list with plot and data
analyze_barplot <- function(cat_var,
                            num_var,
                            stat = c("mean", "sum"),
                            table = "v_head_household_welfare_2023",
                            year = 2023,
                            weight_col = "PENIMBANG_RT",
                            top_n = 15,
                            horizontal = TRUE,
                            filter_sql = NULL,
                            title = NULL,
                            subtitle = NULL,
                            caption = NULL,
                            fill_color = "#1b7837",
                            return_data = FALSE,
                            db_path = NULL) {
  stat <- match.arg(stat)

  # 1. Connect to Database
  con <- get_susenas_con(db_path)
  on.exit(dbDisconnect(con), add = TRUE)

  # 2. SQLite Heavy Aggregation
  where_clauses <- c(
    sprintf("%s IS NOT NULL", cat_var),
    sprintf("TRIM(CAST(%s AS TEXT)) != ''", cat_var),
    sprintf("%s IS NOT NULL", num_var)
  )
  if (!is.null(filter_sql) && nzchar(filter_sql)) {
    where_clauses <- c(where_clauses, sprintf("(%s)", filter_sql))
  }
  where_stmt <- paste(where_clauses, collapse = " AND ")

  stat_expr <- if (stat == "mean") {
    if (!is.null(weight_col) && nzchar(weight_col)) {
      sprintf("SUM(CAST(%s AS REAL) * COALESCE(%s, 1.0)) / SUM(COALESCE(%s, 1.0))", num_var, weight_col, weight_col)
    } else {
      sprintf("AVG(CAST(%s AS REAL))", num_var)
    }
  } else {
    if (!is.null(weight_col) && nzchar(weight_col)) {
      sprintf("SUM(CAST(%s AS REAL) * COALESCE(%s, 1.0))", num_var, weight_col)
    } else {
      sprintf("SUM(CAST(%s AS REAL))", num_var)
    }
  }

  sql_query <- sprintf("
    SELECT 
      CAST(%s AS TEXT) AS cat_raw,
      %s AS stat_val,
      COUNT(*) AS sample_count
    FROM %s
    WHERE %s
    GROUP BY %s
    ORDER BY stat_val DESC;
  ", cat_var, stat_expr, table, where_stmt, cat_var)

  raw_res <- dbGetQuery(con, sql_query)

  if (nrow(raw_res) == 0) {
    warning("Query returned 0 rows. Please check parameters.")
    return(NULL)
  }

  # 3. Tidyverse Post-Processing & Value Labeling
  clean_data <- raw_res %>%
    mutate(
      cat_label = map_value_labels(cat_var, cat_raw, year = year),
      cat_label = ifelse(is.na(cat_label) | cat_label == "", cat_raw, cat_label)
    )

  if (nrow(clean_data) > top_n) {
    clean_data <- clean_data %>% slice_head(n = top_n)
  }

  clean_data <- clean_data %>%
    mutate(
      cat_label = fct_reorder(cat_label, stat_val),
      label_formatted = scales::comma(round(stat_val))
    )

  # Titles & Labels
  stat_label <- if (stat == "mean") "Rata-rata" else "Total"
  plot_title <- if (!is.null(title)) title else sprintf("%s %s menurut %s", stat_label, num_var, cat_var)
  plot_subtitle <- if (!is.null(subtitle)) subtitle else sprintf("Provinsi Jawa Barat, %s%s (Top %d Kategori)", year, ifelse(!is.null(weight_col), " (Terbobot)", " (Sampel)"), min(nrow(clean_data), top_n))
  plot_caption <- if (!is.null(caption)) caption else sprintf("Source: SUSENAS Jawa Barat %s", year)

  # 4. Publication-Ready ggplot2 Visualization
  p <- ggplot(clean_data, aes(x = cat_label, y = stat_val)) +
    geom_col(fill = fill_color, width = 0.68) +
    scale_y_continuous(
      labels = scales::comma,
      expand = expansion(mult = c(0, 0.18))
    ) +
    labs(
      title = plot_title,
      subtitle = plot_subtitle,
      x = NULL,
      y = sprintf("%s %s", stat_label, num_var),
      caption = plot_caption
    ) +
    theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", size = 13, color = "#1a252c"),
      plot.subtitle = element_text(color = "#555555", margin = margin(b = 10)),
      plot.caption = element_text(face = "italic", color = "#666666", size = 9, margin = margin(t = 12)),
      panel.grid.minor = element_blank(),
      axis.text = element_text(color = "#2c3e50")
    )

  if (horizontal) {
    p <- p +
      geom_text(aes(label = label_formatted), hjust = -0.08, size = 3.3, fontface = "bold", color = "#222222") +
      coord_flip() +
      theme(
        panel.grid.major.y = element_blank(),
        axis.text.y = element_text(face = "bold")
      )
  } else {
    p <- p +
      geom_text(aes(label = label_formatted), vjust = -0.4, size = 3.3, fontface = "bold", color = "#222222") +
      theme(
        panel.grid.major.x = element_blank(),
        axis.text.x = element_text(angle = 35, hjust = 1, face = "bold")
      )
  }

  attr(p, "data") <- clean_data
  attr(p, "sql") <- sql_query

  if (return_data) {
    return(list(plot = p, data = clean_data, sql = sql_query))
  }

  p
}

# Standalone Execution Demonstration
if (sys.nframe() == 0L) {
  message(">> Running Barplot Template Demo (PENGELUARAN_PERKAPITA by KODE_KABKOT)...")
  demo_bar <- analyze_barplot(
    cat_var = "KODE_KABKOT",
    num_var = "PENGELUARAN_PERKAPITA",
    stat = "mean",
    top_n = 12,
    horizontal = TRUE,
    title = "Top 12 Daerah dengan Rata-rata Pengeluaran Per Kapita Tertinggi",
    subtitle = "Provinsi Jawa Barat, Susenas 2023 (Rupiah/Bulan Terbobot)"
  )
  out_dir <- file.path("output", "figures")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_file <- file.path(out_dir, "demo_barplot.png")
  ggsave(out_file, demo_bar, width = 9, height = 6, dpi = 300)
  message(sprintf(">> Demo barplot saved to %s", out_file))
}
