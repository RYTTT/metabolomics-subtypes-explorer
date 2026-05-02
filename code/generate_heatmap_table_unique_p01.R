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
  
  # Significant ones (P < 0.01)
  sig <- res_sub %>% filter(P.Value < 0.01)
  all_sig_metabs <- bind_rows(all_sig_metabs, sig)
}

# Find unique metabolites (significant in EXACTLY 1 category)
unique_metabs <- all_sig_metabs %>%
  group_by(Name) %>%
  summarize(n_sig = n()) %>%
  filter(n_sig == 1)

if (nrow(unique_metabs) == 0) {
  cat("No unique metabolites found with P < 0.01 in exactly 1 category.\n")
  q()
}

# Filter all_data for only unique metabolites
heat_data <- all_data %>%
  filter(Name %in% unique_metabs$Name)

# Get list of unique comparisons
comps <- unique(heat_data$Comp)
metabs <- sort(unique(heat_data$Name))

# Create the HTML doc
doc_file <- file.path(dirname(out_dir), "result_FINAL_PRODUCTION", "V12_Unique_Metabolites_Heatmap_P0.01.doc")
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
cat("<h2>Unique Metabolites Heatmap (P < 0.01 in exactly 1 category)</h2>\n")
cat("<p>Colors: <span style='background-color:#ff9999'><b>Red</b></span> = Upregulated (P < 0.01, logFC > 0), <span style='background-color:#99ccff'><b>Blue</b></span> = Downregulated (P < 0.01, logFC < 0).</p>\n")
cat("<p>Significance: ** (P < 0.001), * (P < 0.01). Cells show logFC.</p>\n")

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
      pval <- cell_data$P.Value[1]
      lfc <- cell_data$logFC[1]
      
      if (!is.na(pval) && pval < 0.01) {
        stars <- ifelse(pval < 0.001, "**", "*")
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
