library(dplyr)
library(tidyr)

# Try loading pheatmap, if not installed, install it or use corrplot
if (!requireNamespace("pheatmap", quietly = TRUE)) {
  install.packages("pheatmap", repos = "http://cran.us.r-project.org")
}
library(pheatmap)

out_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/result_V12"
files <- list.files(out_dir, pattern="\\.csv$", full.names=TRUE)
files <- files[!grepl("AutoResearch_Yield", files)]

all_data <- list()

for (f in files) {
  res <- read.csv(f)
  comp <- gsub("\\.csv", "", basename(f))
  
  res$Name <- res$CHEMICAL_NAME
  res$Name[is.na(res$Name) | res$Name == ""] <- as.character(res$Original_ID[is.na(res$Name) | res$Name == ""])
  
  # Select Name and logFC
  df <- res %>% select(Name, logFC)
  
  # Remove duplicates if any (just in case)
  df <- df %>% distinct(Name, .keep_all = TRUE)
  
  colnames(df)[2] <- comp
  all_data[[comp]] <- df
}

# Merge all logFC values
merged_df <- Reduce(function(x, y) full_join(x, y, by="Name"), all_data)

# Extract numeric matrix
mat <- as.matrix(merged_df[,-1])
rownames(mat) <- merged_df$Name

# Compute Pearson correlation matrix using pairwise complete observations
cor_mat <- cor(mat, use="pairwise.complete.obs", method="pearson")

# Save plot
plot_file <- file.path(dirname(out_dir), "result_FINAL_PRODUCTION", "V12_logFC_Correlation_Heatmap.png")
png(plot_file, width=1000, height=800, res=120)

pheatmap(cor_mat, 
         display_numbers = TRUE, 
         fontsize_number = 14, 
         fontsize = 12,
         color = colorRampPalette(c("blue", "white", "red"))(100),
         breaks = seq(-1, 1, length.out = 101),
         main="Pearson Correlation of logFC across 6 categories")

invisible(dev.off())

# Save correlation values to CSV
csv_file <- file.path(dirname(out_dir), "result_FINAL_PRODUCTION", "V12_logFC_Correlation_Matrix.csv")
write.csv(cor_mat, csv_file)

cat("Correlation Heatmap generated at:", plot_file, "\n")
cat("Correlation Matrix saved at:", csv_file, "\n")
