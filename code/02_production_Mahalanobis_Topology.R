# ==============================================================================
# Script: 02_production_Mahalanobis_Topology.R
# Purpose: Formal Geometric Derivation of Subtype Drift
# Author: Meta Subtype Lab Architecture (Antigravity Automation)
#
# Context: Clinical stratification inherently destroys contiguous phenotypic 
#          variance blocks. Rather than arbitrarily testing categorical silos,
#          this algorithm calculates the explicit multidimensional distance 
#          separating an individual traumatized patient's biochemistry away 
#          from the defined control PCA topology manifold.
# ==============================================================================

library(readxl)
library(dplyr)

options(stringsAsFactors = FALSE)
cat(">>> Initiating Production Extractor: Mahalanobis Drift Geometrics ...\n")

# 1. CORE DIRECTORIES
working_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/"
input_path <- file.path(working_dir, "Meta subtype  Antigravity", "resource", "Bridged metabolomics data_subtype analysis_2026.4.22_NEW CONTROLS-2.xlsx")
anno_path <- file.path(working_dir, "Bridged metabolomics data_subtype analysis_2025.12.18 V3.xlsx")
out_dir <- file.path(working_dir, "Meta subtype  Antigravity", "result_FINAL_PRODUCTION")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# 2. DATA REGISTRATION (V12 Subset Pipeline Assumed directly)
metab_data <- read_excel(input_path, sheet = "LogGroup-norm Data Bridged wImp")
annotation <- read_excel(anno_path, sheet = "annotation")
status_df <- read_excel(input_path, sheet = "ID match & status") %>% distinct(Metabolon_ID, .keep_all = TRUE)
demo_df <- read_excel(input_path, sheet = "demographics") %>% distinct(Metabolon_ID, .keep_all = TRUE)
metadata <- full_join(status_df, demo_df, by = "Metabolon_ID") %>%
  mutate(PTSD_status_binary = case_when(!is.na(`NEW Control group status`) & `NEW Control group status` == "Control" ~ "Control", 
                                          !is.na(`OLD CATEGORY_PTSD_status_binary`) & `OLD CATEGORY_PTSD_status_binary` == "PTSD" ~ "PTSD", TRUE ~ NA_character_))
common_samples <- intersect(metab_data$PARENT_SAMPLE_NAME, metadata$Metabolon_ID)
m_data <- metab_data %>% filter(PARENT_SAMPLE_NAME %in% common_samples) %>% arrange(PARENT_SAMPLE_NAME)
m_meta <- metadata %>% filter(Metabolon_ID %in% common_samples) %>% arrange(Metabolon_ID)

mat <- t(as.matrix(m_data %>% select(-PARENT_SAMPLE_NAME)))
colnames(mat) <- m_data$PARENT_SAMPLE_NAME
m_meta <- m_meta %>% mutate(Age=as.numeric(Age), BMI=as.numeric(BMI), Gender=as.factor(Gender))
idx <- complete.cases(m_meta[, c("Age", "Gender", "BMI")])
m_meta <- m_meta[idx, ]; mat <- mat[, idx]
keep_ids <- m_meta %>% filter(!is.na(PTSD_status_binary)) %>% pull(Metabolon_ID)
m_meta <- m_meta %>% filter(Metabolon_ID %in% keep_ids)
mat <- mat[, m_meta$Metabolon_ID]

priority <- c("serotonin", "5-HIAA", "tryptophan", "tryptamine", "melatonin", "dopamine", "dopac", "homovanillate", "norepinephrine", "epinephrine", "glutamate", "glutamine", "GABA", "acetylcholine", "choline", "histamine", "histidine")
v12_sig <- (annotation$SUB_PATHWAY %in% c("TCA Cycle", "Oxidative Phosphorylation", "Ceramides", "Sphingomyelins", "Phosphatidylcholine (PC)", "Lysophospholipid", "Progestin Steroids")) | grepl("docosa", annotation$CHEMICAL_NAME) | grepl(paste(priority, collapse="|"), annotation$CHEMICAL_NAME, ignore.case=T)
mat <- mat[rownames(mat) %in% as.character(annotation$CHEM_ID[v12_sig]), ]

# 3. CONSTRUCT CENTRAL HEALTHY MANIFOLD
idx_control <- m_meta$PTSD_status_binary == "Control"
mat_control <- mat[, idx_control]

# Deriving the multi-dimensional feature space uniquely characterizing basal health
pca_control <- prcomp(t(mat_control), scale. = TRUE)
mean_pc <- colMeans(pca_control$x[, 1:5])
cov_pc <- cov(pca_control$x[, 1:5])

# Project overall array down identical eigenvectors
all_projected <- scale(t(mat), center = pca_control$center, scale = pca_control$scale) %*% pca_control$rotation[, 1:5]

# Geometric Measurement Matrix
m_dist <- mahalanobis(all_projected, center = mean_pc, cov = cov_pc)
m_meta$Geometric_Distance <- m_dist

# 4. CLINICAL OUTPUT COMPILATION
summary_dist <- m_meta %>%
  group_by(four_subtypes) %>%
  summarize(Mean_Mahalanobis_Drift = mean(Geometric_Distance, na.rm=TRUE),
            Median_Mahalanobis_Drift = median(Geometric_Distance, na.rm=TRUE),
            Geometric_Variance = sd(Geometric_Distance, na.rm=TRUE))

print(summary_dist)
write.csv(summary_dist, file.path(out_dir, "02_Topology_Subtype_Geometric_Drift.csv"), row.names=FALSE)
cat(">>> Pipeline Terminated Successfully. Topological coordinates registered locally.\n")
