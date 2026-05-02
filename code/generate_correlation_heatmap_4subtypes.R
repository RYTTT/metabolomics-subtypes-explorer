library(dplyr)
library(tidyr)
library(pheatmap)

out_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/result_V12"
files <- list.files(out_dir, pattern="\\.csv$", full.names=TRUE)
files <- files[!grepl("AutoResearch_Yield", files)]

# Filter for the 4 subtypes
target_comps <- c("Subtypes_Cognitive_vs_Control", "Subtypes_Depressive_vs_Control", "Subtypes_MildPTSD_vs_Control", "Subtypes_SeverePTSD_vs_Control")
files <- files[sapply(files, function(f) any(sapply(target_comps, function(tc) grepl(tc, f))))]

all_data <- list()

for (f in files) {
  res <- read.csv(f)
  comp <- gsub("\\.csv", "", basename(f))
  
  # Clean names
  comp <- gsub("Subtypes_", "", comp)
  comp <- gsub("_vs_Control", "", comp)
  
  res$Name <- res$CHEMICAL_NAME
  res$Name[is.na(res$Name) | res$Name == ""] <- as.character(res$Original_ID[is.na(res$Name) | res$Name == ""])
  
  df <- res %>% select(Name, logFC)
  df <- df %>% distinct(Name, .keep_all = TRUE)
  colnames(df)[2] <- comp
  all_data[[comp]] <- df
}

merged_df <- Reduce(function(x, y) full_join(x, y, by="Name"), all_data)

mat <- as.matrix(merged_df[,-1])
rownames(mat) <- merged_df$Name

cor_mat <- cor(mat, use="pairwise.complete.obs", method="pearson")

# Save plot
plot_file <- file.path(dirname(out_dir), "result_FINAL_PRODUCTION", "V12_logFC_Correlation_Heatmap_4Subtypes.png")
png(plot_file, width=800, height=800, res=120)

pheatmap(cor_mat, 
         display_numbers = TRUE, 
         fontsize_number = 16, 
         fontsize = 14,
         color = colorRampPalette(c("blue", "white", "red"))(100),
         breaks = seq(-1, 1, length.out = 101),
         main="Pearson Correlation of logFC across 4 Subtypes")

invisible(dev.off())

# Also save a PDF version
plot_file_pdf <- file.path(dirname(out_dir), "result_FINAL_PRODUCTION", "V12_logFC_Correlation_Heatmap_4Subtypes.pdf")
pdf(plot_file_pdf, width=8, height=8)

pheatmap(cor_mat, 
         display_numbers = TRUE, 
         fontsize_number = 16, 
         fontsize = 14,
         color = colorRampPalette(c("blue", "white", "red"))(100),
         breaks = seq(-1, 1, length.out = 101),
         main="Pearson Correlation of logFC across 4 Subtypes")

invisible(dev.off())

cat("Done!\n")
