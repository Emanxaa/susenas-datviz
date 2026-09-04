# R/boxplot_template.R
# Reusable Boxplot Analysis Template for SUSENAS Workflows
# Strategy: Efficient columnar filtering in SQLite -> tidyverse median reordering & labeling -> publication ggplot2

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

#' Generate Distribution Boxplot from SUSENAS SQLite Database
#'
#' @param num_var Numeric continuous variable name (e.g., 'PENGELUARAN_PERKAPITA', 'TOTAL_PENGELUARAN', 'KALORI_PERKAPITA')
#' @param group_var Categorical grouping variable name (e.g., 'KLASIFIKASI_PERKOTAAN_PERDESAAN', 'PENDIDIKAN_TERTINGGI_KRT')
#' @param table Table or View name in SQLite (default: 'v_head_household_welfare_2023')
#' @param year Survey year (default: 2023)
#' @param log_scale Logical. If TRUE, applies log10 scaling to numeric axis (recommended for expenditure metrics, default: TRUE)
#' @param flip_coords Logical. If TRUE, flips coordinates for legible category labels (default: TRUE)
#' @param top_n Maximum number of groups to plot (default: 12)
#' @param filter_sql Optional SQL WHERE clause condition
#' @param title Custom plot title (optional)
#' @param subtitle Custom plot subtitle (default: "Provinsi Jawa Barat, {year}")
#' @param caption Custom plot caption (default: "Source: SUSENAS Jawa Barat {year}")
#' @param palette Color palette vector
#' @param return_data Logical. If TRUE, returns list(plot = p, summary_stats = stats, raw_data = df, sql = query). If FALSE, returns ggplot object.
#' @param db_path Path to SQLite susenas.db (optional, auto-resolved if NULL)
#' @return ggplot object or list with plot and stats
analyze_boxplot <- function(num_var,
                            group_var,
                            table = "v_head_household_welfare_2023",
                            year = 2023,
                            log_scale = TRUE,
                            flip_coords = TRUE,
                            top_n = 12,
                            filter_sql = NULL,
                            title = NULL,
                            subtitle = NULL,
                            caption = NULL,
                            palette = NULL,
                            return_data = FALSE,
                            db_path = NULL) {
  # 1. Connect to Database
  con <- get_susenas_con(db_path)
  on.exit(dbDisconnect(con), add = TRUE)

  # 2. SQLite Filtered Query (Only fetch required non-null columns)
  where_clauses <- c(
    sprintf("%s IS NOT NULL", num_var),
    sprintf("CAST(%s AS REAL) > 0", num_var),
    sprintf("%s IS NOT NULL", group_var),
    sprintf("TRIM(CAST(%s AS TEXT)) != ''", group_var)
  )
  if (!is.null(filter_sql) && nzchar(filter_sql)) {
    where_clauses <- c(where_clauses, sprintf("(%s)", filter_sql))
  }
  where_stmt <- paste(where_clauses, collapse = " AND ")

  sql_query <- sprintf("
    SELECT 
      CAST(%s AS TEXT) AS group_raw,
      CAST(%s AS REAL) AS num_val
    FROM %s
    WHERE %s;
  ", group_var, num_var, table, where_stmt)

  raw_res <- dbGetQuery(con, sql_query)

  if (nrow(raw_res) == 0) {
    warning("Query returned 0 rows. Please verify variable names and filters.")
    return(NULL)
  }

  # 3. Tidyverse Post-Processing & Value Labeling
  clean_data <- raw_res %>%
    mutate(
      group_label = map_value_labels(group_var, group_raw, year = year),
      group_label = ifelse(is.na(group_label) | group_label == "", group_raw, group_label)
    )

  # Collapse categories exceeding top_n by frequency
  top_groups <- clean_data %>%
    count(group_label, sort = TRUE) %>%
    slice_head(n = top_n) %>%
    pull(group_label)

  clean_data <- clean_data %>%
    filter(group_label %in% top_groups)

  # Calculate group summary stats (Median, IQR, Mean)
  group_stats <- clean_data %>%
    group_by(group_label) %>%
    summarise(
      n = n(),
      mean_val = mean(num_val, na.rm = TRUE),
      median_val = median(num_val, na.rm = TRUE),
      q25 = quantile(num_val, 0.25, na.rm = TRUE),
      q75 = quantile(num_val, 0.75, na.rm = TRUE),
      iqr = q75 - q25,
      .groups = "drop"
    ) %>%
    arrange(desc(median_val))

  # Reorder factor levels by median
  clean_data <- clean_data %>%
    mutate(group_label = fct_reorder(group_label, num_val, .fun = median))

  # Formatting & Titles
  plot_title <- if (!is.null(title)) title else paste("Distribusi", num_var, "menurut", group_var)
  scale_desc <- if (log_scale) "(Skala Logaritmik)" else "(Skala Linier)"
  plot_subtitle <- if (!is.null(subtitle)) subtitle else sprintf("Provinsi Jawa Barat, %s %s", year, scale_desc)
  plot_caption <- if (!is.null(caption)) caption else sprintf("Source: SUSENAS Jawa Barat %s", year)

  # Colors
  n_cats <- length(unique(clean_data$group_label))
  default_palette <- c("#2b5c8f", "#d95f02", "#1b9e77", "#7570b3", "#e7298a", "#66a61e", "#e6ab02", "#a6761d", "#666666")
  active_palette <- if (!is.null(palette)) palette else rep_len(default_palette, n_cats)

  # 4. Publication-Ready ggplot2 Visualization
  p <- ggplot(clean_data, aes(x = group_label, y = num_val, fill = group_label)) +
    geom_boxplot(
      alpha = 0.75,
      outlier.size = 0.8,
      outlier.alpha = 0.2,
      outlier.color = "#777777",
      width = 0.6,
      show.legend = FALSE
    ) +
    scale_fill_manual(values = active_palette) +
    labs(
      title = plot_title,
      subtitle = plot_subtitle,
      x = NULL,
      y = paste("Nilai", num_var),
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

  if (log_scale) {
    p <- p + scale_y_log10(
      labels = scales::comma,
      expand = expansion(mult = c(0.05, 0.08))
    )
  } else {
    p <- p + scale_y_continuous(
      labels = scales::comma,
      expand = expansion(mult = c(0.05, 0.08))
    )
  }

  if (flip_coords) {
    p <- p + coord_flip() +
      theme(
        panel.grid.major.y = element_blank(),
        axis.text.y = element_text(face = "bold")
      )
  } else {
    p <- p +
      theme(
        panel.grid.major.x = element_blank(),
        axis.text.x = element_text(angle = 35, hjust = 1, face = "bold")
      )
  }

  attr(p, "summary_stats") <- group_stats
  attr(p, "data") <- clean_data
  attr(p, "sql") <- sql_query

  if (return_data) {
    return(list(plot = p, summary_stats = group_stats, raw_data = clean_data, sql = sql_query))
  }

  p
}

# Standalone Execution Demonstration
if (sys.nframe() == 0L) {
  message(">> Running Boxplot Template Demo (PENGELUARAN_PERKAPITA by KLASIFIKASI_PERKOTAAN_PERDESAAN)...")
  demo_boxplot <- analyze_boxplot(
    num_var = "PENGELUARAN_PERKAPITA",
    group_var = "KLASIFIKASI_PERKOTAAN_PERDESAAN",
    log_scale = TRUE,
    title = "Sebaran Pengeluaran Per Kapita: Perkotaan vs Perdesaan",
    subtitle = "Provinsi Jawa Barat, Susenas 2023 (Skala Logaritmik Rupiah)"
  )
  out_dir <- file.path("output", "figures")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_file <- file.path(out_dir, "demo_boxplot.png")
  ggsave(out_file, demo_boxplot, width = 8.5, height = 5, dpi = 300)
  message(sprintf(">> Demo boxplot saved to %s", out_file))
}
