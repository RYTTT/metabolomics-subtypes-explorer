library(readxl)
library(dplyr)

cat("Executing First Principles II and III (Entropy & Geometrics)...\n")

working_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/"
file_name <- "Bridged metabolomics data_subtype analysis_2026.4.22_NEW CONTROLS-2.xlsx"
input_path <- file.path(working_dir, "Meta subtype  Antigravity", "resource", file_name)
out_dir <- file.path(working_dir, "Meta subtype  Antigravity", "result_Causal", "First_Principles")

metab_data <- read_excel(input_path, sheet = "LogGroup-norm Data Bridged wImp")
annotation_path <- file.path(working_dir, "Bridged metabolomics data_subtype analysis_2025.12.18 V3.xlsx")
annotation <- read_excel(annotation_path, sheet = "annotation")
status_df <- read_excel(input_path, sheet = "ID match & status") %>% distinct(Metabolon_ID, .keep_all = TRUE)
demo_df <- read_excel(input_path, sheet = "demographics") %>% distinct(Metabolon_ID, .keep_all = TRUE)

metadata <- full_join(status_df, demo_df, by = "Metabolon_ID") %>%
  mutate(PTSD_status_binary = case_when(!is.na(`NEW Control group status`) & `NEW Control group status` == "Control" ~ "Control", !is.na(`OLD CATEGORY_PTSD_status_binary`) & `OLD CATEGORY_PTSD_status_binary` == "PTSD" ~ "PTSD", TRUE ~ NA_character_))
data_samples <- metab_data$PARENT_SAMPLE_NAME
metadata <- metadata %>% filter(Metabolon_ID %in% data_samples)

common_samples <- intersect(data_samples, metadata$Metabolon_ID)
m_data <- metab_data %>% filter(PARENT_SAMPLE_NAME %in% common_samples) %>% arrange(PARENT_SAMPLE_NAME)
m_meta <- metadata %>% filter(Metabolon_ID %in% common_samples) %>% arrange(Metabolon_ID)

mat <- t(as.matrix(m_data %>% select(-PARENT_SAMPLE_NAME)))
colnames(mat) <- m_data$PARENT_SAMPLE_NAME
m_meta <- m_meta %>% mutate(Age=as.numeric(Age), BMI=as.numeric(BMI), Gender=as.factor(Gender), Cohort=as.factor(Cohort))

# Keep only those with known binary status
keep_ids <- m_meta %>% filter(!is.na(PTSD_status_binary)) %>% pull(Metabolon_ID)
m_meta <- m_meta %>% filter(Metabolon_ID %in% keep_ids)
mat <- mat[, m_meta$Metabolon_ID]

# V12 Filter
priority <- c("serotonin", "5-HIAA", "tryptophan", "tryptamine", "melatonin", "dopamine", "dopac", "3,4-dihydroxyphenylacetate", "homovanillate", "homovanillic acid", "3-methoxytyramine", "norepinephrine", "noradrenaline", "epinephrine", "adrenaline", "metanephrine", "normetanephrine", "vanillylmandelate", "VMA", "glutamate", "glutamine", "GABA", "gamma-aminobutyrate", "acetylcholine", "choline", "histamine", "histidine")
v12 <- rep(FALSE, nrow(annotation))
for(p in priority) v12 <- v12 | grepl(paste0("\\b",p,"\\b"), annotation$CHEMICAL_NAME, ignore.case=TRUE)
mat <- mat[rownames(mat) %in% as.character(annotation$CHEM_ID[v12]), ]


# -------------------------------------------------------------------------
# PRINCIPLE II: Pathological Entropy Mapping (Differential Variance)
# -------------------------------------------------------------------------
cat("Mapping Differential Homeostatic Variance...\n")
# Testing if Depressive PTSD has exploded variance compared to Controls (Loss of control)
sub_m <- m_meta %>% mutate(Grp = case_when(four_subtypes == "Depressive Symptom Subtype" ~ "Depressive", PTSD_status_binary == "Control" ~ "Control", TRUE ~ NA_character_)) %>% filter(!is.na(Grp))
sub_mat <- mat[, sub_m$Metabolon_ID]

var_pvals <- c()
for(i in 1:nrow(sub_mat)) {
  res <- tryCatch(var.test(sub_mat[i, sub_m$Grp == "Depressive"], sub_mat[i, sub_m$Grp == "Control"])$p.value, error=function(e) NA)
  var_pvals <- c(var_pvals, res)
}

res_var <- data.frame(CHEM_ID = rownames(sub_mat), Var_P_Value = var_pvals) %>% mutate(CHEM_ID = as.numeric(CHEM_ID))
res_var <- left_join(res_var, annotation %>% select(CHEM_ID, CHEMICAL_NAME), by="CHEM_ID") %>% arrange(Var_P_Value)
write.csv(res_var %>% filter(Var_P_Value < 0.05), file.path(out_dir, "Pathological_Entropy_Depressive.csv"), row.names=FALSE)

# -------------------------------------------------------------------------
# PRINCIPLE III: Mahalanobis Distance Geometric Mapping
# -------------------------------------------------------------------------
cat("Calculating Manifold Distance Coordinates...\n")

# Compute the "Super Healthy Baseline Manifold" using PCA on the Controls only.
idx_control <- m_meta$PTSD_status_binary == "Control"
mat_control <- mat[, idx_control]

# Compute PCA space of controls
pca_control <- prcomp(t(mat_control), scale. = TRUE)
# Take top 5 PCs to define the core healthy manifold
mean_pc <- colMeans(pca_control$x[, 1:5])
cov_pc <- cov(pca_control$x[, 1:5])

# Project ALL patients (Controls + PTSD) into this healthy coordinate space
all_projected <- scale(t(mat), center = pca_control$center, scale = pca_control$scale) %*% pca_control$rotation[, 1:5]

# Calculate Mahalanobis Distance for every subject away from the healthy manifold centroid
m_dist <- mahalanobis(all_projected, center = mean_pc, cov = cov_pc)

m_meta$Geometric_Distance <- m_dist

# Identify the mean geometric drift for each subtype
summary_dist <- m_meta %>%
  group_by(four_subtypes) %>%
  summarize(Mean_Mahalanobis = mean(Geometric_Distance, na.rm=TRUE),
            Median_Mahalanobis = median(Geometric_Distance, na.rm=TRUE))

print(summary_dist)
write.csv(summary_dist, file.path(out_dir, "Subtype_Geometric_Distance_Drift.csv"), row.names=FALSE)

cat("Geo-Variance metrics successfully integrated.\n")
