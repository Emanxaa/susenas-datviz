# R/proportion_template.R
# Reusable Proportion Analysis Template for SUSENAS Workflows
# Strategy: Aggregation in SQLite -> tidyverse for proportions & labels -> publication ggplot2

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

#' Generate Proportion Analysis & Visualization (Bar / Donut) from SUSENAS SQLite Database
#'
#' @param var Column name of the categorical variable to analyze (e.g., 'KLASIFIKASI_PERKOTAAN_PERDESAAN', 'JENIS_KELAMIN_KRT')
#' @param table Table or View name in SQLite (default: 'v_head_household_welfare_2023')
#' @param year Survey year (default: 2023)
#' @param weight_col Sampling weight column (default: 'PENIMBANG_RT'; set NULL for unweighted)
#' @param chart_type Character, either "bar" (proportional bar) or "donut" (default: "bar")
#' @param filter_sql Optional SQL WHERE clause condition
#' @param title Custom plot title (optional)
#' @param subtitle Custom plot subtitle (default: "Provinsi Jawa Barat, {year}")
#' @param caption Custom plot caption (default: "Source: SUSENAS Jawa Barat {year}")
#' @param palette Color palette for categories (default: c("#2b5c8f", "#e6550d", "#31a354", "#756bb1", "#636363"))
#' @param return_data Logical. If TRUE, returns list(plot = p, data = df, sql = query). If FALSE, returns ggplot object.
#' @param db_path Path to SQLite susenas.db (optional, auto-resolved if NULL)
#' @return ggplot object or list with plot and data
analyze_proportion <- function(var,
                               table = "v_head_household_welfare_2023",
                               year = 2023,
                               weight_col = "PENIMBANG_RT",
                               chart_type = c("bar", "donut"),
                               filter_sql = NULL,
                               title = NULL,
                               subtitle = NULL,
                               caption = NULL,
                               palette = NULL,
                               return_data = FALSE,
                               db_path = NULL) {
  chart_type <- match.arg(chart_type)

  # 1. Database Connection
  con <- get_susenas_con(db_path)
  on.exit(dbDisconnect(con), add = TRUE)

  # 2. Query SQLite (Aggregate at Database Level)
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

  raw_res <- dbGetQuery(con, sql_query)

  if (nrow(raw_res) == 0) {
    warning("Query returned 0 rows. Please verify parameters.")
    return(NULL)
  }

  # 3. Tidyverse Post-Processing
  clean_data <- raw_res %>%
    mutate(
      category_raw = as.character(category_raw),
      category_label = map_value_labels(var, category_raw, year = year),
      category_label = ifelse(is.na(category_label) | category_label == "", as.character(category_raw), category_label)
    )

  total_weighted <- sum(clean_data$weighted_count, na.rm = TRUE)
  clean_data <- clean_data %>%
    mutate(
      prop = weighted_count / total_weighted,
      pct = prop * 100,
      label_pct = sprintf("%.1f%%", pct),
      label_full = sprintf("%s\n(%.1f%%)", category_label, pct),
      category_label = fct_reorder(category_label, weighted_count)
    )

  # Default publication color palette
  default_palette <- c("#2b5c8f", "#e6550d", "#2ca25f", "#756bb1", "#fa8c16", "#13c2c2", "#722ed1", "#eb2f96")
  active_palette <- if (!is.null(palette)) palette else default_palette[1:nrow(clean_data)]

  # Titles & Captions
  plot_title <- if (!is.null(title)) title else paste("Proporsi:", var)
  plot_subtitle <- if (!is.null(subtitle)) subtitle else sprintf("Provinsi Jawa Barat, %s%s", year, ifelse(!is.null(weight_col), " (Terbobot)", " (Sampel)"))
  plot_caption <- if (!is.null(caption)) caption else sprintf("Source: SUSENAS Jawa Barat %s", year)

  # 4. ggplot2 Rendering
  if (chart_type == "bar") {
    p <- ggplot(clean_data, aes(x = category_label, y = pct, fill = category_label)) +
      geom_col(width = 0.6, show.legend = FALSE) +
      geom_text(aes(label = sprintf("%.1f%% (%s)", pct, scales::comma(round(weighted_count)))),
                hjust = -0.05, size = 3.5, fontface = "bold", color = "#222222") +
      scale_y_continuous(
        labels = function(x) paste0(x, "%"),
        expand = expansion(mult = c(0, 0.25))
      ) +
      scale_fill_manual(values = active_palette) +
      coord_flip() +
      labs(
        title = plot_title,
        subtitle = plot_subtitle,
        x = NULL,
        y = "Proporsi Terbobot (%)",
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
  } else {
    # Donut Chart
    clean_data <- clean_data %>%
      arrange(desc(category_label)) %>%
      mutate(
        ymax = cumsum(prop),
        ymin = c(0, head(ymax, n = -1)),
        label_pos = (ymax + ymin) / 2
      )

    p <- ggplot(clean_data, aes(ymax = ymax, ymin = ymin, xmax = 4, xmin = 2.8, fill = category_label)) +
      geom_rect(color = "white", linewidth = 1.2) +
      geom_text(aes(x = 3.4, y = label_pos, label = sprintf("%s\n%.1f%%", category_label, pct)),
                color = "white", fontface = "bold", size = 3.6) +
      coord_polar(theta = "y") +
      xlim(c(1.5, 4.5)) +
      scale_fill_manual(values = active_palette) +
      labs(
        title = plot_title,
        subtitle = plot_subtitle,
        caption = plot_caption,
        fill = NULL
      ) +
      theme_void(base_size = 11) +
      theme(
        plot.title = element_text(face = "bold", size = 13, color = "#1a252c", hjust = 0.5),
        plot.subtitle = element_text(color = "#555555", hjust = 0.5, margin = margin(b = 10)),
        plot.caption = element_text(face = "italic", color = "#666666", size = 9, margin = margin(t = 12), hjust = 0.95),
        legend.position = "bottom"
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
  message(">> Running Proportion Template Demo (KLASIFIKASI_PERKOTAAN_PERDESAAN)...")
  demo_bar <- analyze_proportion(
    var = "KLASIFIKASI_PERKOTAAN_PERDESAAN",
    chart_type = "bar",
    title = "Proporsi Rumah Tangga Menurut Klasifikasi Wilayah",
    subtitle = "Provinsi Jawa Barat, Susenas 2023"
  )
  demo_donut <- analyze_proportion(
    var = "JENIS_KELAMIN_KRT",
    chart_type = "donut",
    title = "Proporsi Kepala Rumah Tangga Berdasarkan Jenis Kelamin",
    subtitle = "Provinsi Jawa Barat, Susenas 2023"
  )
  out_dir <- file.path("output", "figures")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  ggsave(file.path(out_dir, "demo_proportion_bar.png"), demo_bar, width = 8, height = 5, dpi = 300)
  ggsave(file.path(out_dir, "demo_proportion_donut.png"), demo_donut, width = 7, height = 6, dpi = 300)
  message(">> Demo proportion plots saved.")
}
