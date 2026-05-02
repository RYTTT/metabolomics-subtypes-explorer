options(stringsAsFactors = FALSE)
library(dplyr)

v12_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/result_V12"

files <- c(
  "Subtypes_Depressive_vs_Control.csv",
  "Subtypes_Cognitive_vs_Control.csv",
  "Subtypes_MildPTSD_vs_Control.csv",
  "Subtypes_SeverePTSD_vs_Control.csv",
  "Cognitive_CogPos_vs_Control.csv",
  "Cognitive_CogPos_vs_CogNeg.csv"
)

color_item <- function(name, logfc) {
  col <- ifelse(is.na(logfc), "black", ifelse(logfc > 0, "red", "blue"))
  esc <- gsub("&", "&amp;", name, fixed = TRUE)
  esc <- gsub("<", "&lt;", esc, fixed = TRUE)
  esc <- gsub(">", "&gt;", esc, fixed = TRUE)
  paste0("<span style=\"color:", col, "\">", esc, "</span>")
}

make_row <- function(fn) {
  f <- file.path(v12_dir, fn)
  if (!file.exists(f)) return(NULL)
  
  d <- read.csv(f)
  
  if (!"V12_panel" %in% colnames(d)) return(NULL)

  dp <- d %>% filter(V12_panel == TRUE)
  
  if (!"CHEMICAL_NAME" %in% colnames(dp)) dp$CHEMICAL_NAME <- as.character(dp$CHEM_ID)
  dp$CHEMICAL_NAME <- as.character(dp$CHEMICAL_NAME)
  
  n_p05 <- sum(dp$P.Value < 0.05, na.rm = TRUE)
  n_p01 <- sum(dp$P.Value < 0.01, na.rm = TRUE)
  n_fdr01 <- sum(dp$adj.P.Val < 0.1, na.rm = TRUE)

  hits <- dp %>% filter(!is.na(P.Value) & P.Value < 0.01) %>% arrange(P.Value)
  
  if (nrow(hits) == 0) {
    list_str <- ""
  } else {
    u <- !duplicated(hits$CHEMICAL_NAME)
    hits_u <- hits[u, ]
    colored <- mapply(color_item, hits_u$CHEMICAL_NAME, hits_u$logFC, USE.NAMES = FALSE)
    list_str <- paste(colored, collapse = "; ")
  }

  cn <- sub(".csv$", "", fn)
  # Prettify Comparison name
  cn <- sub("^Subtypes_", "", cn)
  cn <- sub("^Cognitive_", "", cn)
  
  data.frame(
    Comparison = cn,
    `P < 0.05` = n_p05,
    `P < 0.01` = n_p01,
    `FDR < 0.1` = n_fdr01,
    `DE Metabolites (P < 0.01)` = list_str,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

rows <- lapply(files, make_row)
rows <- bind_rows(rows[!sapply(rows, is.null)])

md <- c(
  "# DE Metabolites Summary (v12 panel)",
  "",
  "Based on the new control set (`result_V12` folder). Colors: <span style=\"color:red\">**red**</span> = upregulated (logFC > 0), <span style=\"color:blue\">**blue**</span> = downregulated (logFC < 0). Only showing metabolites with P < 0.01.",
  "",
  "| Comparison | P < 0.05 | P < 0.01 | FDR < 0.1 | P < 0.01 Metabolites |",
  "|---|---|---|---|---|"
)

for (i in seq_len(nrow(rows))) {
  r <- rows[i, ]
  md <- c(md, paste(
    "|", r$Comparison,
    "|", r$`P < 0.05`,
    "|", r$`P < 0.01`,
    "|", r$`FDR < 0.1`,
    "|", r$`DE Metabolites (P < 0.01)`, "|"
  ))
}

out_md <- file.path(v12_dir, "V12_DE_summary_red_blue.md")
writeLines(md, out_md)
cat(out_md)
