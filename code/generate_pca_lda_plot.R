library(readxl)
library(dplyr)
library(ggplot2)
library(MASS) # For LDA

cat("Generating PCA-LDA plot...\n")

working_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/"
input_path <- file.path(working_dir, "Meta subtype  Antigravity", "resource", "Bridged metabolomics data_subtype analysis_2026.4.22_NEW CONTROLS-2.xlsx")
out_dir <- file.path(working_dir, "Meta subtype  Antigravity", "result_FINAL_PRODUCTION")

# Load data
metab_data <- read_excel(input_path, sheet = "LogGroup-norm Data Bridged wImp")
status_df <- read_excel(input_path, sheet = "ID match & status") %>% distinct(Metabolon_ID, .keep_all = TRUE)

# Merge metadata with metabolomics
metab_data <- metab_data %>% rename(Metabolon_ID = PARENT_SAMPLE_NAME)

merged_data <- inner_join(status_df %>% dplyr::select(Metabolon_ID, four_subtypes), metab_data, by = "Metabolon_ID")

# Filter out NAs
plot_data <- merged_data %>% filter(!is.na(four_subtypes))

# Convert Group to factor for LDA
plot_data$four_subtypes <- as.factor(plot_data$four_subtypes)

# Extract metabolomics matrix
metab_matrix <- as.matrix(plot_data %>% dplyr::select(-Metabolon_ID, -four_subtypes))
class(metab_matrix) <- "numeric"

# Remove any columns with zero variance or all NAs
valid_cols <- apply(metab_matrix, 2, function(x) var(x, na.rm = TRUE) > 0)
metab_matrix <- metab_matrix[, valid_cols]

# -------------------------------------------------------------------------
# High-Dimensional LDA Strategy: PCA-LDA
# We cannot run LDA directly on 1000+ features because the smallest group 
# (Depressive) only has 32 samples (collinearity / rank deficiency).
# Instead, we reduce the data to the top 20 Principal Components, then run LDA.
# -------------------------------------------------------------------------

# Run PCA
pca_res <- prcomp(metab_matrix, scale. = TRUE, center = TRUE)

# Extract top 20 PCs
num_pcs <- 20
pca_scores <- as.data.frame(pca_res$x[, 1:num_pcs])
pca_scores$Group <- plot_data$four_subtypes

# Run LDA on the PCs
lda_model <- lda(Group ~ ., data = pca_scores)

# Predict LDA scores
lda_pred <- predict(lda_model)

# The proportion of trace (variance explained by each LD)
lda_prop <- round(lda_model$svd^2 / sum(lda_model$svd^2) * 100, 1)

# Create a data frame for plotting
lda_df <- data.frame(
  Sample = plot_data$Metabolon_ID,
  Group = plot_data$four_subtypes,
  LD1 = lda_pred$x[, 1],
  LD2 = lda_pred$x[, 2]
)

# Create plot
p <- ggplot(lda_df, aes(x = LD1, y = LD2, color = Group)) +
  geom_point(alpha = 0.8, size = 2) +
  stat_ellipse(aes(fill = Group), geom = "polygon", alpha = 0.1, type = "t") +
  theme_minimal() +
  labs(
    title = "PCA-LDA of Metabolomics Data by Subtype",
    subtitle = sprintf("LDA performed on the first %d Principal Components", num_pcs),
    x = sprintf("LD1 (%.1f%% Trace)", lda_prop[1]),
    y = sprintf("LD2 (%.1f%% Trace)", lda_prop[2])
  ) +
  theme(
    legend.position = "right",
    plot.title = element_text(hjust = 0.5, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5)
  ) +
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1")

# Save plot
plot_file <- file.path(out_dir, "V12_Metabolites_PCA_LDA_Subtypes.png")
ggsave(plot_file, plot = p, width = 9, height = 7, dpi = 300)

cat("PCA-LDA plot successfully generated at:", plot_file, "\n")
