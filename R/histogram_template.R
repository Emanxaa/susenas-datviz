# R/histogram_template.R
# Reusable Histogram Analysis Template for SUSENAS Workflows
# Strategy: Efficient numeric querying in SQLite -> tidyverse for distribution stats -> publication ggplot2

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

#' Generate Continuous Histogram & Density Plot from SUSENAS SQLite Database
#'
#' @param num_var Numeric continuous column name (e.g., 'PENGELUARAN_PERKAPITA', 'KALORI_PERKAPITA', 'PROTEIN_PERKAPITA')
#' @param table Table or View name in SQLite (default: 'v_head_household_welfare_2023')
#' @param year Survey year (default: 2023)
#' @param bins Number of histogram bins (default: 35)
#' @param log_scale Logical. If TRUE, applies log10 scaling to the numeric axis (default: FALSE)
#' @param add_density Logical. If TRUE, overlays a kernel density curve (default: TRUE)
#' @param add_markers Logical. If TRUE, draws vertical indicator lines for Mean and Median (default: TRUE)
#' @param filter_sql Optional SQL WHERE clause condition (e.g., "PENGELUARAN_PERKAPITA <= 5000000")
#' @param title Custom plot title (optional)
#' @param subtitle Custom plot subtitle (default: "Provinsi Jawa Barat, {year}")
#' @param caption Custom plot caption (default: "Source: SUSENAS Jawa Barat {year}")
#' @param fill_color Fill color for histogram bars (default: "#3182bd")
#' @param return_data Logical. If TRUE, returns list(plot = p, summary_stats = stats, raw_data = df, sql = query). If FALSE, returns ggplot object.
#' @param db_path Path to SQLite susenas.db (optional, auto-resolved if NULL)
#' @return ggplot object or list with plot and stats
analyze_histogram <- function(num_var,
                              table = "v_head_household_welfare_2023",
                              year = 2023,
                              bins = 35,
                              log_scale = FALSE,
                              add_density = TRUE,
                              add_markers = TRUE,
                              filter_sql = NULL,
                              title = NULL,
                              subtitle = NULL,
                              caption = NULL,
                              fill_color = "#3182bd",
                              return_data = FALSE,
                              db_path = NULL) {
  # 1. Connect to Database
  con <- get_susenas_con(db_path)
  on.exit(dbDisconnect(con), add = TRUE)

  # 2. SQLite Filtered Query
  where_clauses <- c(
    sprintf("%s IS NOT NULL", num_var),
    sprintf("CAST(%s AS REAL) > 0", num_var)
  )
  if (!is.null(filter_sql) && nzchar(filter_sql)) {
    where_clauses <- c(where_clauses, sprintf("(%s)", filter_sql))
  }
  where_stmt <- paste(where_clauses, collapse = " AND ")

  sql_query <- sprintf("
    SELECT CAST(%s AS REAL) AS num_val
    FROM %s
    WHERE %s;
  ", num_var, table, where_stmt)

  raw_res <- dbGetQuery(con, sql_query)

  if (nrow(raw_res) == 0) {
    warning("Query returned 0 rows. Please check parameters and filters.")
    return(NULL)
  }

  # 3. Tidyverse Post-Processing & Distribution Summary
  clean_data <- raw_res %>%
    filter(!is.na(num_val))

  mean_val <- mean(clean_data$num_val, na.rm = TRUE)
  median_val <- median(clean_data$num_val, na.rm = TRUE)
  sd_val <- sd(clean_data$num_val, na.rm = TRUE)
  p25_val <- quantile(clean_data$num_val, 0.25, na.rm = TRUE)
  p75_val <- quantile(clean_data$num_val, 0.75, na.rm = TRUE)
  p95_val <- quantile(clean_data$num_val, 0.95, na.rm = TRUE)

  stats_summary <- tibble(
    variable = num_var,
    n_sample = nrow(clean_data),
    mean = mean_val,
    median = median_val,
    sd = sd_val,
    q25 = p25_val,
    q75 = p75_val,
    p95 = p95_val
  )

  # Titles & Subtitles
  plot_title <- if (!is.null(title)) title else paste("Distribusi Frekuensi:", num_var)
  scale_txt <- if (log_scale) "(Skala Logaritmik)" else "(Skala Asli)"
  plot_subtitle <- if (!is.null(subtitle)) subtitle else sprintf(
    "Provinsi Jawa Barat, %s %s | Mean: %s, Median: %s",
    year, scale_txt, scales::comma(round(mean_val)), scales::comma(round(median_val))
  )
  plot_caption <- if (!is.null(caption)) caption else sprintf("Source: SUSENAS Jawa Barat %s", year)

  # 4. Publication-Ready ggplot2 Visualization
  p <- ggplot(clean_data, aes(x = num_val))

  if (add_density) {
    p <- p + geom_histogram(
      aes(y = after_stat(density)),
      bins = bins,
      fill = fill_color,
      color = "white",
      alpha = 0.78
    ) +
    geom_density(
      color = "#d73027",
      linewidth = 1.05,
      adjust = 1.2
    ) +
    scale_y_continuous(labels = scales::scientific_format(digits = 2)) +
    labs(y = "Kepadatan Peluang (Density)")
  } else {
    p <- p + geom_histogram(
      bins = bins,
      fill = fill_color,
      color = "white",
      alpha = 0.85
    ) +
    scale_y_continuous(labels = scales::comma) +
    labs(y = "Jumlah Rumah Tangga / Sampel")
  }

  if (log_scale) {
    p <- p + scale_x_log10(
      labels = scales::comma,
      expand = expansion(mult = c(0.02, 0.05))
    )
  } else {
    p <- p + scale_x_continuous(
      labels = scales::comma,
      expand = expansion(mult = c(0.02, 0.05))
    )
  }

  if (add_markers) {
    p <- p +
      geom_vline(
        xintercept = mean_val,
        color = "#d73027",
        linetype = "dashed",
        linewidth = 0.95
      ) +
      geom_vline(
        xintercept = median_val,
        color = "#1a9850",
        linetype = "dotted",
        linewidth = 1.1
      ) +
      annotate(
        "text",
        x = mean_val,
        y = Inf,
        label = sprintf("Mean: %s", scales::comma(round(mean_val))),
        vjust = 2.0,
        hjust = -0.08,
        color = "#d73027",
        size = 3.2,
        fontface = "bold"
      ) +
      annotate(
        "text",
        x = median_val,
        y = Inf,
        label = sprintf("Median: %s", scales::comma(round(median_val))),
        vjust = 4.0,
        hjust = -0.08,
        color = "#1a9850",
        size = 3.2,
        fontface = "bold"
      )
  }

  p <- p +
    labs(
      title = plot_title,
      subtitle = plot_subtitle,
      x = paste("Nilai", num_var),
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

  attr(p, "summary_stats") <- stats_summary
  attr(p, "data") <- clean_data
  attr(p, "sql") <- sql_query

  if (return_data) {
    return(list(plot = p, summary_stats = stats_summary, raw_data = clean_data, sql = sql_query))
  }

  p
}

# Standalone Execution Demonstration
if (sys.nframe() == 0L) {
  message(">> Running Histogram Template Demo (KALORI_PERKAPITA)...")
  demo_hist <- analyze_histogram(
    num_var = "KALORI_PERKAPITA",
    bins = 40,
    add_density = TRUE,
    add_markers = TRUE,
    filter_sql = "KALORI_PERKAPITA <= 6000",
    title = "Distribusi Konsumsi Kalori Per Kapita Sehari",
    subtitle = "Provinsi Jawa Barat, Susenas 2023 (Kkal/Kapita/Hari)"
  )
  out_dir <- file.path("output", "figures")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_file <- file.path(out_dir, "demo_histogram.png")
  ggsave(out_file, demo_hist, width = 8.5, height = 5, dpi = 300)
  message(sprintf(">> Demo histogram saved to %s", out_file))
}
