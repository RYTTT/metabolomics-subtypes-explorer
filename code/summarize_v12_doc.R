library(dplyr)

out_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/result_FINAL_PRODUCTION/IPW_V12_Six_Comparisons"
files <- list.files(out_dir, pattern="\\.csv$", full.names=TRUE)

doc_file <- file.path(dirname(out_dir), "V12_DE_summary.doc")
sink(doc_file)

cat("<html><head><meta charset='utf-8'></head><body>\n")
cat("<h2>DE Metabolites Summary (v12 panel)</h2>\n")
cat("<p>Based on the new control set (<code>result_FINAL_PRODUCTION</code> folder). Colors: <span style='color:red'><b>red</b></span> = upregulated (logFC > 0), <span style='color:blue'><b>blue</b></span> = downregulated (logFC < 0).</p>\n")

cat("<table border='1' style='border-collapse: collapse; width: 100%;'>\n")
cat("<tr>\n")
cat("<th>Comparison</th><th>P < 0.05</th><th>P < 0.01</th><th>FDR < 0.1</th><th>P < 0.01 Metabolites</th><th>FDR < 0.1 Metabolites</th>\n")
cat("</tr>\n")

for (f in files) {
  res <- read.csv(f)
  comp <- gsub("\\.csv", "", basename(f))
  
  p05 <- sum(res$P.Value < 0.05, na.rm=TRUE)
  p01 <- sum(res$P.Value < 0.01, na.rm=TRUE)
  fdr1 <- sum(res$adj.P.Val < 0.1, na.rm=TRUE)
  
  format_metabs <- function(res_subset) {
    if (nrow(res_subset) == 0) return("")
    metabs <- sapply(1:nrow(res_subset), function(i) {
      name <- res_subset$CHEMICAL_NAME[i]
      if(is.na(name) || name == "") name <- as.character(res_subset$Original_ID[i])
      
      stars <- ""
      if(!is.na(res_subset$adj.P.Val[i])) {
        if (res_subset$adj.P.Val[i] < 0.05) stars <- "**"
        else if (res_subset$adj.P.Val[i] < 0.1) stars <- "*"
      }
      
      fc <- res_subset$logFC[i]
      color <- ifelse(fc > 0, "red", "blue")
      sprintf("<span style='color:%s'>%s%s</span>", color, name, stars)
    })
    paste(metabs, collapse="; ")
  }
  
  res01 <- res %>% filter(P.Value < 0.01) %>% arrange(P.Value)
  res_fdr1 <- res %>% filter(adj.P.Val < 0.1) %>% arrange(adj.P.Val)
  
  metabs_01_str <- format_metabs(res01)
  metabs_fdr1_str <- format_metabs(res_fdr1)
  
  cat("<tr>\n")
  cat(sprintf("<td>%s</td><td>%d</td><td>%d</td><td>%d</td><td>%s</td><td>%s</td>\n", 
              comp, p05, p01, fdr1, metabs_01_str, metabs_fdr1_str))
  cat("</tr>\n")
}

cat("</table>\n")
cat("</body></html>\n")

sink()
cat("Word document generated at:", doc_file, "\n")
