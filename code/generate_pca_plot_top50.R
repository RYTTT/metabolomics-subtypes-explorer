library(readxl)
library(dplyr)
library(ggplot2)

cat("Generating Top 50 Most Variable Metabolites PCA plot...\n")

working_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/"
input_path <- file.path(working_dir, "Meta subtype  Antigravity", "resource", "Bridged metabolomics data_subtype analysis_2026.4.22_NEW CONTROLS-2.xlsx")
out_dir <- file.path(working_dir, "Meta subtype  Antigravity", "result_FINAL_PRODUCTION")

# Load data
metab_data <- read_excel(input_path, sheet = "LogGroup-norm Data Bridged wImp")
status_df <- read_excel(input_path, sheet = "ID match & status") %>% distinct(Metabolon_ID, .keep_all = TRUE)

# Merge metadata with metabolomics
# Rename for join
metab_data <- metab_data %>% rename(Metabolon_ID = PARENT_SAMPLE_NAME)

merged_data <- inner_join(status_df %>% select(Metabolon_ID, four_subtypes), metab_data, by = "Metabolon_ID")

# Filter out NAs
plot_data <- merged_data %>% filter(!is.na(four_subtypes))

# Extract metabolomics matrix
metab_matrix <- as.matrix(plot_data %>% select(-Metabolon_ID, -four_subtypes))
# Ensure numeric
class(metab_matrix) <- "numeric"

# Remove any columns with zero variance or all NAs (just in case)
valid_cols <- apply(metab_matrix, 2, function(x) var(x, na.rm = TRUE) > 0)
metab_matrix <- metab_matrix[, valid_cols]

# Calculate variance for each metabolite
feature_vars <- apply(metab_matrix, 2, var, na.rm = TRUE)

# Select top 50 most variable
top_50_features <- names(sort(feature_vars, decreasing = TRUE)[1:50])
metab_matrix_top50 <- metab_matrix[, top_50_features]

# Run PCA
pca_res <- prcomp(metab_matrix_top50, scale. = TRUE, center = TRUE)

# Extract first two PCs
pca_df <- data.frame(
  Sample = plot_data$Metabolon_ID,
  Group = plot_data$four_subtypes,
  PC1 = pca_res$x[, 1],
  PC2 = pca_res$x[, 2]
)

# Calculate variance explained
var_explained <- summary(pca_res)$importance[2, 1:2] * 100

# Create plot
p <- ggplot(pca_df, aes(x = PC1, y = PC2, color = Group)) +
  geom_point(alpha = 0.8, size = 2) +
  stat_ellipse(aes(fill = Group), geom = "polygon", alpha = 0.1, type = "t") +
  theme_minimal() +
  labs(
    title = "PCA of Top 50 Most Variable Metabolites by Subtype",
    x = sprintf("PC1 (%.1f%%)", var_explained[1]),
    y = sprintf("PC2 (%.1f%%)", var_explained[2])
  ) +
  theme(
    legend.position = "right",
    plot.title = element_text(hjust = 0.5, face = "bold")
  ) +
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1")

# Save plot
plot_file <- file.path(out_dir, "V12_Metabolites_PCA_Subtypes_Top50.png")
ggsave(plot_file, plot = p, width = 9, height = 7, dpi = 300)

cat("PCA plot successfully generated at:", plot_file, "\n")
