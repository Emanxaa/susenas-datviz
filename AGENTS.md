# SUSENAS Agent Rules

## Stack

- R
- SQLite
- tidyverse
- ggplot2
- Quarto

## Context Priority

1. User request
2. survey_catalog
3. variable_registry
4. join_registry
5. Relevant metadata page
6. SQL result

Never load full PDFs or CSVs.

## Workflow

- Search metadata first.
- Use SQLite for filtering and aggregation.
- Use tidyverse after SQL.
- Use ggplot2 for figures.
- Keep code runnable.

## Never

- Invent variables.
- Invent codebook definitions.
- Guess joins.

## Default Output

Variables → SQL → R → Plot → Interpretation → Source.