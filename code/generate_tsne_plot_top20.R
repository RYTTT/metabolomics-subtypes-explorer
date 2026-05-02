library(readxl)
library(dplyr)
library(ggplot2)
library(Rtsne)

cat("Generating Top 20 Most Variable Metabolites t-SNE plot...\n")

working_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/"
input_path <- file.path(working_dir, "Meta subtype  Antigravity", "resource", "Bridged metabolomics data_subtype analysis_2026.4.22_NEW CONTROLS-2.xlsx")
out_dir <- file.path(working_dir, "Meta subtype  Antigravity", "result_FINAL_PRODUCTION")

# Load data
metab_data <- read_excel(input_path, sheet = "LogGroup-norm Data Bridged wImp")
status_df <- read_excel(input_path, sheet = "ID match & status") %>% distinct(Metabolon_ID, .keep_all = TRUE)

# Merge metadata with metabolomics
metab_data <- metab_data %>% rename(Metabolon_ID = PARENT_SAMPLE_NAME)

merged_data <- inner_join(status_df %>% select(Metabolon_ID, four_subtypes), metab_data, by = "Metabolon_ID")

# Filter out NAs
plot_data <- merged_data %>% filter(!is.na(four_subtypes))

# Extract metabolomics matrix
metab_matrix <- as.matrix(plot_data %>% select(-Metabolon_ID, -four_subtypes))
class(metab_matrix) <- "numeric"

# Remove any columns with zero variance or all NAs
valid_cols <- apply(metab_matrix, 2, function(x) var(x, na.rm = TRUE) > 0)
metab_matrix <- metab_matrix[, valid_cols]

# Calculate variance for each metabolite
feature_vars <- apply(metab_matrix, 2, var, na.rm = TRUE)

# Select top 20 most variable
top_20_features <- names(sort(feature_vars, decreasing = TRUE)[1:20])
metab_matrix_top20 <- metab_matrix[, top_20_features]

# Scale for t-SNE
metab_matrix_top20 <- scale(metab_matrix_top20)

# Run t-SNE
set.seed(42) # Set seed for reproducibility
tsne_res <- Rtsne(metab_matrix_top20, dims = 2, perplexity = 30, max_iter = 1000, check_duplicates = FALSE)

# Extract first two PCs (well, t-SNE dims)
tsne_df <- data.frame(
  Sample = plot_data$Metabolon_ID,
  Group = plot_data$four_subtypes,
  tSNE1 = tsne_res$Y[, 1],
  tSNE2 = tsne_res$Y[, 2]
)

# Create plot
p <- ggplot(tsne_df, aes(x = tSNE1, y = tSNE2, color = Group)) +
  geom_point(alpha = 0.8, size = 2) +
  stat_ellipse(aes(fill = Group), geom = "polygon", alpha = 0.1, type = "t") +
  theme_minimal() +
  labs(
    title = "t-SNE of Top 20 Most Variable Metabolites by Subtype",
    x = "t-SNE Dimension 1",
    y = "t-SNE Dimension 2"
  ) +
  theme(
    legend.position = "right",
    plot.title = element_text(hjust = 0.5, face = "bold")
  ) +
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1")

# Save plot
plot_file <- file.path(out_dir, "V12_Metabolites_tSNE_Subtypes_Top20.png")
ggsave(plot_file, plot = p, width = 9, height = 7, dpi = 300)

cat("t-SNE plot successfully generated at:", plot_file, "\n")
