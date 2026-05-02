library(dplyr)
library(tidyr)

out_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/result_V12"
files <- list.files(out_dir, pattern="\\.csv$", full.names=TRUE)
files <- files[!grepl("AutoResearch_Yield", files)]

all_sig_metabs <- data.frame()
all_data <- data.frame()

# Load all data and identify significant hits
for (f in files) {
  res <- read.csv(f)
  comp <- gsub("\\.csv", "", basename(f))
  
  # Clean up name
  res$Name <- res$CHEMICAL_NAME
  res$Name[is.na(res$Name) | res$Name == ""] <- as.character(res$Original_ID[is.na(res$Name) | res$Name == ""])
  
  res$Comp <- comp
  
  # Keep relevant columns
  res_sub <- res %>% select(Name, logFC, P.Value, adj.P.Val, Comp)
  all_data <- bind_rows(all_data, res_sub)
  
  # Significant ones
  sig <- res_sub %>% filter(adj.P.Val < 0.1)
  all_sig_metabs <- bind_rows(all_sig_metabs, sig)
}

# Find common metabolites (significant in >= 2 categories)
common_metabs <- all_sig_metabs %>%
  group_by(Name) %>%
  summarize(n_sig = n()) %>%
  filter(n_sig >= 2)

if (nrow(common_metabs) == 0) {
  cat("No common metabolites found with FDR < 0.1 in >= 2 categories.\n")
  q()
}

# Filter all_data for only common metabolites
heat_data <- all_data %>%
  filter(Name %in% common_metabs$Name)

# Get list of unique comparisons
comps <- unique(heat_data$Comp)
metabs <- sort(unique(heat_data$Name))

# Create the HTML doc
doc_file <- file.path(dirname(out_dir), "result_FINAL_PRODUCTION", "V12_Common_Metabolites_Heatmap.doc")
sink(doc_file)

cat("<html><head><meta charset='utf-8'>\n")
cat("<style>\n")
cat("table { border-collapse: collapse; width: 100%; font-family: Arial, sans-serif; font-size: 12px; }\n")
cat("th, td { border: 1px solid #ddd; padding: 4px; text-align: center; }\n")
cat("th { background-color: #f2f2f2; }\n")
cat(".up { background-color: #ff9999; color: black; }\n")
cat(".down { background-color: #99ccff; color: black; }\n")
cat(".none { background-color: #ffffff; color: #ccc; }\n")
cat("</style>\n")
cat("</head><body>\n")
cat("<h2>Common Metabolites Heatmap (FDR < 0.1 in >= 2 categories)</h2>\n")
cat("<p>Colors: <span style='background-color:#ff9999'><b>Red</b></span> = Upregulated (FDR < 0.1, logFC > 0), <span style='background-color:#99ccff'><b>Blue</b></span> = Downregulated (FDR < 0.1, logFC < 0).</p>\n")
cat("<p>Significance: ** (FDR < 0.05), * (FDR < 0.1). Cells show logFC.</p>\n")

cat("<table>\n")
cat("<tr><th>Metabolite</th>")
for (c in comps) {
  cat(sprintf("<th>%s</th>", c))
}
cat("</tr>\n")

for (m in metabs) {
  cat("<tr>")
  cat(sprintf("<td style='text-align: left;'><b>%s</b></td>", m))
  for (c in comps) {
    cell_data <- heat_data %>% filter(Name == m, Comp == c)
    if (nrow(cell_data) == 0) {
      cat("<td class='none'>-</td>")
    } else {
      pval <- cell_data$adj.P.Val[1]
      lfc <- cell_data$logFC[1]
      
      if (!is.na(pval) && pval < 0.1) {
        stars <- ifelse(pval < 0.05, "**", "*")
        css_class <- ifelse(lfc > 0, "up", "down")
        val_str <- sprintf("%.2f %s", lfc, stars)
        cat(sprintf("<td class='%s'>%s</td>", css_class, val_str))
      } else {
        # Not significant
        val_str <- sprintf("%.2f", lfc)
        cat(sprintf("<td class='none'>%s</td>", val_str))
      }
    }
  }
  cat("</tr>\n")
}

cat("</table>\n")
cat("</body></html>\n")

sink()
cat("Heatmap generated at:", doc_file, "\n")
