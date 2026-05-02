library(dplyr)

out_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/result_FINAL_PRODUCTION/IPW_V12_Six_Comparisons"
files <- list.files(out_dir, pattern="\\.csv$", full.names=TRUE)

# Open markdown file connection
md_file <- file.path(dirname(out_dir), "V12_DE_summary.md")
sink(md_file)

cat("# DE Metabolites Summary (v12 panel)\n\n")
cat("Based on the new control set (`result_FINAL_PRODUCTION` folder). Colors: <span style=\"color:red\">**red**</span> = upregulated (logFC > 0), <span style=\"color:blue\">**blue**</span> = downregulated (logFC < 0). \n\n")

cat("| Comparison | P < 0.05 | P < 0.01 | FDR < 0.1 | P < 0.01 Metabolites | FDR < 0.1 Metabolites |\n")
cat("|---|---|---|---|---|---|\n")

for (f in files) {
  res <- read.csv(f)
  comp <- gsub("\\.csv", "", basename(f))
  
  p05 <- sum(res$P.Value < 0.05, na.rm=TRUE)
  p01 <- sum(res$P.Value < 0.01, na.rm=TRUE)
  fdr1 <- sum(res$adj.P.Val < 0.1, na.rm=TRUE)
  
  # Format function
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
      sprintf('<span style="color:%s">%s%s</span>', color, name, stars)
    })
    paste(metabs, collapse="; ")
  }
  
  res01 <- res %>% filter(P.Value < 0.01) %>% arrange(P.Value)
  res_fdr1 <- res %>% filter(adj.P.Val < 0.1) %>% arrange(adj.P.Val)
  
  metabs_01_str <- format_metabs(res01)
  metabs_fdr1_str <- format_metabs(res_fdr1)
  
  cat(sprintf("| %s | %d | %d | %d | %s | %s |\n", comp, p05, p01, fdr1, metabs_01_str, metabs_fdr1_str))
}

sink()
cat("Markdown generated at:", md_file, "\n")
