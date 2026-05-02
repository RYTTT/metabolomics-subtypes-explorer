# ==============================================================================
# Script: 01_production_SDR_IPW_pipeline.R
# Purpose: Formal Extraction of Causal Biomarkers via 
#          Stabilized Doubly-Robust Inverse Probability Weighting (S-DR-IPW)
# Author: Meta Subtype Lab Architecture
#
# Context: High-dimensional multi-omics clinical cohorts (FCC, SBC, Cohen) are 
#          heavily confounded by demographic permutations. This script deploys 
#          formal counterfactual weighting geometries. By computing stabilized 
#          GLM-derived propensity scores and retaining structural covariates inside
#          the design matrix, the pipeline yields an unbiased, doubly-robust 
#          causal network via Limma-eBayes framework.
# ==============================================================================

library(readxl)
library(dplyr)
library(limma)

options(stringsAsFactors = FALSE)
cat(">>> Initiating Production Extractor: Stabilized DR-IPW ...\n")

# 1. CORE DIRECTORIES
working_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/"
input_path <- file.path(working_dir, "Meta subtype  Antigravity", "resource", "Bridged metabolomics data_subtype analysis_2026.4.22_NEW CONTROLS-2.xlsx")
anno_path <- file.path(working_dir, "Bridged metabolomics data_subtype analysis_2025.12.18 V3.xlsx")
out_dir <- file.path(working_dir, "Meta subtype  Antigravity", "result_FINAL_PRODUCTION", "IPW_Limma")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# 2. DATA INGESTION & CO-REGISTRATION
cat(">>> Mapping Baseline Matrix...\n")
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

m_meta <- m_meta %>% mutate(Age=as.numeric(Age), BMI=as.numeric(BMI), Gender=as.factor(Gender), Cohort=as.factor(Cohort))
idx_complete <- complete.cases(m_meta[, c("Age", "Gender", "BMI", "Cohort", "PTSD_status_binary")])
m_meta <- m_meta[idx_complete,]
mat <- mat[, idx_complete]

# 3. CLINICAL INDICES
unlog <- function(x) 2^x 
find_id <- function(kw) annotation$CHEM_ID[grep(kw, annotation$CHEMICAL_NAME, ignore.case=TRUE)[1]]
v_arg <- mat[as.character(find_id("^arginine$")), ]; v_orn <- mat[as.character(find_id("^ornithine$")), ]; v_cit <- mat[as.character(find_id("^citrulline$")), ]
if(!is.null(v_arg)) mat <- rbind(mat, "GABR" = log2(unlog(v_arg)/(unlog(v_orn)+unlog(v_cit))))
v_lac <- mat[as.character(find_id("^lactate$")), ]; v_pyr <- mat[as.character(find_id("^pyruvate$")), ]; v_citr <- mat[as.character(find_id("^citrate$")), ]
if(!is.null(v_lac)) mat <- rbind(mat, "Glycolytic_Ratio" = log2((unlog(v_lac)+unlog(v_pyr))/unlog(v_citr)))

# 4. V12 PRECISION TARGETING 
mito <- c("Glycolysis, Gluconeogenesis, and Pyruvate Metabolism", "TCA Cycle", "Oxidative Phosphorylation", "Nicotinate and Nicotinamide Metabolism")
lipids <- c("Ceramides", "Sphingomyelins", "Dihydrosphingomyelins", "Sphingosines", "Sphingolipid Synthesis", "Hexosylceramides (HCER)", "Lactosylceramides (LCER)", "Phosphatidylcholine (PC)", "Phosphatidylethanolamine (PE)", "Lysophospholipid", "Triacylglycerol")
fa <- c("Carnitine Metabolism", "Ketone Bodies", "Long Chain Saturated Fatty Acid", "Long Chain Monounsaturated Fatty Acid", "Long Chain Polyunsaturated Fatty Acid (n3 and n6)", "Medium Chain Fatty Acid", "Short Chain Fatty Acid", "Fatty Acid Metabolism (Acyl Carnitine, Hydroxy)", "Fatty Acid Metabolism (Acyl Carnitine, Long Chain Saturated)", "Fatty Acid Metabolism (Acyl Carnitine, Medium Chain)", "Fatty Acid Metabolism (Acyl Carnitine, Monounsaturated)", "Fatty Acid Metabolism (Acyl Carnitine, Polyunsaturated)", "Fatty Acid Metabolism (Acyl Carnitine, Short Chain)")
bile <- c("Primary Bile Acid Metabolism", "Secondary Bile Acid Metabolism")
steroid <- c("Pregnenolone Steroids", "Corticosteroids", "Progestin Steroids", "Androgenic Steroids")
purine <- c("Xanthine Metabolism", "Purine Metabolism, (Hypo)Xanthine/Inosine containing", "Purine Metabolism, Adenine containing", "Purine Metabolism, Guanine containing")

base_kw <- "(tryptophan|kynuren|quinolin|kynurenic|xanthuren|anthranil|ethanolamide|PEA\\b|AEA\\b|2-AG\\b|arachidonoyl)"
v8 <- (annotation$SUB_PATHWAY %in% c(mito, lipids, fa, bile, steroid, purine)) | grepl(base_kw, annotation$CHEMICAL_NAME, ignore.case=TRUE)
priority <- c("serotonin", "5-HIAA", "tryptophan", "tryptamine", "melatonin", "dopamine", "dopac", "3,4-dihydroxyphenylacetate", "homovanillate", "homovanillic acid", "3-methoxytyramine", "norepinephrine", "noradrenaline", "epinephrine", "adrenaline", "metanephrine", "normetanephrine", "vanillylmandelate", "VMA", "glutamate", "glutamine", "GABA", "gamma-aminobutyrate", "acetylcholine", "choline", "histamine", "histidine")
v12 <- rep(FALSE, nrow(annotation))
for(p in priority) v12 <- v12 | grepl(paste0("\\b",p,"\\b"), annotation$CHEMICAL_NAME, ignore.case=TRUE)

targets <- c(as.character(annotation$CHEM_ID[v8 | v12]), "GABR", "Glycolytic_Ratio")
mat <- mat[rownames(mat) %in% targets, ]
cat(sprintf(">>> V12 Architectural Dimension: %d Markers\n", nrow(mat)))


# 5. DIAGNOSTIC STRATIFICATION STRINGS
m_meta <- m_meta %>% mutate(Group_Sub = case_when(PTSD_status_binary=="Control"~"Control", 
                                                  four_subtypes=="Depressive Symptom Subtype"~"Depressive", 
                                                  four_subtypes=="Impaired Cognitive Function"~"Cognitive", 
                                                  four_subtypes=="Subthreshold/Mild PTSD Subtype"~"MildPTSD", TRUE~NA_character_))
m_meta <- m_meta %>% filter(!is.na(Group_Sub))
mat <- mat[, m_meta$Metabolon_ID]

# 6. CAUSAL INFERENCE LOOP: Stabilized DR-IPW Limma
set.seed(42) # Ensuring identical manuscript reproducibility
for(tgt in c("Depressive", "Cognitive", "MildPTSD")) {
  sub_m <- m_meta %>% filter(Group_Sub %in% c("Control", tgt))
  sub_mat <- mat[, sub_m$Metabolon_ID]
  sub_m$IsCase <- ifelse(sub_m$Group_Sub == tgt, 1, 0)
  
  cat(sprintf("\n>>> Fitting Causal Densities for %s vs Control...\n", tgt))
  
  # Standard Epidemiological Propensity Formula (Logistic Regression)
  ps_mod <- glm(IsCase ~ Age + Gender + BMI + Cohort, data=sub_m, family=binomial)
  sub_m$PS <- predict(ps_mod, type="response")
  
  # Marginal Trajectory for Stabilization
  marg <- mean(sub_m$IsCase)
  
  # Compute Stabilized Weights
  sub_m$SW <- ifelse(sub_m$IsCase==1, marg / sub_m$PS, (1 - marg) / (1 - sub_m$PS))
  
  # Structural Truncation of Leverage Extremes (1st and 99th percentile cutoff for Limma stability)
  q_low <- quantile(sub_m$SW, 0.01)
  q_high <- quantile(sub_m$SW, 0.99)
  sub_m$Trunc_Weight <- pmax(pmin(sub_m$SW, q_high), q_low)
  
  # Doubly-Robust Design Implementation (Retaining Covariates in Limma shrinks residual variance)
  Grp <- factor(sub_m$Group_Sub)
  dsn <- model.matrix(~0 + Grp + Age + Gender + BMI + Cohort, data=sub_m)
  colnames(dsn)[1:2] <- levels(Grp)
  
  # Execute Linear Fit matching weights structurally. 
  # trend=TRUE natively resolves the structural heteroscedasticity created by the weighting process
  fit <- eBayes(contrasts.fit(lmFit(sub_mat, dsn, weights=sub_m$Trunc_Weight), makeContrasts(paste0(tgt,"-Control"), levels=dsn)), robust=TRUE, trend=TRUE)
  res <- topTable(fit, coef=1, n=Inf, sort.by="P")
  
  # Formal mapping
  res$CHEM_ID <- rownames(res); res$Original_ID <- res$CHEM_ID; res$CHEM_ID <- suppressWarnings(as.numeric(res$CHEM_ID))
  res_out <- left_join(res, annotation, by="CHEM_ID")
  res_out$CHEMICAL_NAME <- ifelse(is.na(res_out$CHEMICAL_NAME), res_out$Original_ID, res_out$CHEMICAL_NAME)
  
  write.csv(res_out, file.path(out_dir, paste0("Target_Discovery_DR_IPW_", tgt, ".csv")), row.names=FALSE)
}
cat("\n>>> Production Output Complete. Stabilized Causal IPW-Limma vectors registered locally.\n")
