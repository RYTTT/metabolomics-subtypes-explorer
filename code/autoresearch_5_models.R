library(readxl)
library(dplyr)
library(limma)
library(stringr)
library(sva)

working_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/"
file_name <- "Bridged metabolomics data_subtype analysis_2026.4.22_NEW CONTROLS-2.xlsx"
input_path <- file.path(working_dir, "Meta subtype  Antigravity", "resource", file_name)

# ----------------------------------------------------
# 1. LOAD DATA & METADATA (Exact V12 Pipeline)
# ----------------------------------------------------
metab_data <- read_excel(input_path, sheet = "LogGroup-norm Data Bridged wImp")
annotation_path <- file.path(working_dir, "Bridged metabolomics data_subtype analysis_2025.12.18 V3.xlsx")
annotation <- read_excel(annotation_path, sheet = "annotation")
status_df <- read_excel(input_path, sheet = "ID match & status") %>% distinct(Metabolon_ID, .keep_all = TRUE)
demo_df <- read_excel(input_path, sheet = "demographics") %>% distinct(Metabolon_ID, .keep_all = TRUE)

metadata <- full_join(status_df, demo_df, by = "Metabolon_ID") %>%
  mutate(
    PTSD_status_binary = case_when(
      !is.na(`NEW Control group status`) & `NEW Control group status` == "Control" ~ "Control",
      !is.na(`OLD CATEGORY_PTSD_status_binary`) & `OLD CATEGORY_PTSD_status_binary` == "PTSD" ~ "PTSD",
      TRUE ~ NA_character_
    )
  )

data_samples <- metab_data$PARENT_SAMPLE_NAME
metadata <- metadata %>% filter(Metabolon_ID %in% data_samples)

common_samples <- intersect(metab_data$PARENT_SAMPLE_NAME, metadata$Metabolon_ID)
metab_data_filtered <- metab_data %>% filter(PARENT_SAMPLE_NAME %in% common_samples) %>% arrange(PARENT_SAMPLE_NAME)
metadata_filtered <- metadata %>% filter(Metabolon_ID %in% common_samples) %>% arrange(Metabolon_ID)

mat <- t(as.matrix(metab_data_filtered %>% select(-PARENT_SAMPLE_NAME)))
colnames(mat) <- metab_data_filtered$PARENT_SAMPLE_NAME

metadata_filtered <- metadata_filtered %>%
  mutate(Age = as.numeric(Age), BMI = as.numeric(BMI), Gender = as.factor(Gender), Cohort = as.factor(Cohort))

complete_cases_idx <- complete.cases(metadata_filtered[, c("Age", "Gender", "BMI")])
metadata_final <- metadata_filtered[complete_cases_idx, ]
mat_final <- mat[, complete_cases_idx]

# V12 Bypass PSM (Use all curated controls)
keep_ids <- metadata_final %>% filter(!is.na(PTSD_status_binary)) %>% pull(Metabolon_ID)
metadata_final <- metadata_final %>% filter(Metabolon_ID %in% keep_ids)
mat_final <- mat_final[, metadata_final$Metabolon_ID]

# Index Calculation (GABR, Glycolytic)
unlog <- function(x) 2^x 
find_id_by_name <- function(keyword, anno_df) {
  hits <- anno_df[grep(paste0("^", keyword, "$"), anno_df$CHEMICAL_NAME, ignore.case = TRUE), ]
  if (nrow(hits) == 0) hits <- anno_df[grep(keyword, anno_df$CHEMICAL_NAME, ignore.case = TRUE), ]
  if (nrow(hits) > 0) return(hits$CHEM_ID[1])
  return(NULL)
}
vec_arg <- mat_final[as.character(find_id_by_name("arginine", annotation)), ]
vec_orn <- mat_final[as.character(find_id_by_name("ornithine", annotation)), ]
vec_cit <- mat_final[as.character(find_id_by_name("citrulline", annotation)), ]
if (!is.null(vec_arg) && !is.null(vec_orn) && !is.null(vec_cit)) mat_final <- rbind(mat_final, "GABR" = log2(unlog(vec_arg) / (unlog(vec_orn) + unlog(vec_cit))))

vec_lac <- mat_final[as.character(find_id_by_name("lactate", annotation)), ]
vec_pyr <- mat_final[as.character(find_id_by_name("pyruvate", annotation)), ]
vec_citr <- mat_final[as.character(find_id_by_name("citrate", annotation)), ]
if (!is.null(vec_lac) && !is.null(vec_pyr) && !is.null(vec_citr)) mat_final <- rbind(mat_final, "Glycolytic_Ratio" = log2((unlog(vec_lac) + unlog(vec_pyr)) / unlog(vec_citr)))

# V12 Filtering Lock
mito_subpaths <- c("Glycolysis, Gluconeogenesis, and Pyruvate Metabolism", "TCA Cycle", "Oxidative Phosphorylation", "Nicotinate and Nicotinamide Metabolism")
lipid_subpaths <- c("Ceramides", "Sphingomyelins", "Dihydrosphingomyelins", "Sphingosines", "Sphingolipid Synthesis", "Hexosylceramides (HCER)", "Lactosylceramides (LCER)", "Phosphatidylcholine (PC)", "Phosphatidylethanolamine (PE)", "Lysophospholipid", "Triacylglycerol")
fa_subpaths <- c("Carnitine Metabolism", "Ketone Bodies", "Long Chain Saturated Fatty Acid", "Long Chain Monounsaturated Fatty Acid", "Long Chain Polyunsaturated Fatty Acid (n3 and n6)", "Medium Chain Fatty Acid", "Short Chain Fatty Acid", "Fatty Acid Metabolism (Acyl Carnitine, Hydroxy)", "Fatty Acid Metabolism (Acyl Carnitine, Long Chain Saturated)", "Fatty Acid Metabolism (Acyl Carnitine, Medium Chain)", "Fatty Acid Metabolism (Acyl Carnitine, Monounsaturated)", "Fatty Acid Metabolism (Acyl Carnitine, Polyunsaturated)", "Fatty Acid Metabolism (Acyl Carnitine, Short Chain)")
bile_subpaths <- c("Primary Bile Acid Metabolism", "Secondary Bile Acid Metabolism")
steroid_subpaths <- c("Pregnenolone Steroids", "Corticosteroids", "Progestin Steroids", "Androgenic Steroids")
purine_subpaths <- c("Xanthine Metabolism", "Purine Metabolism, (Hypo)Xanthine/Inosine containing", "Purine Metabolism, Adenine containing", "Purine Metabolism, Guanine containing")

base_keywords <- "(tryptophan|kynuren|quinolin|kynurenic|xanthuren|anthranil|ethanolamide|PEA\\b|AEA\\b|2-AG\\b|arachidonoyl)"
annotation$PTSDBioPriority_v8 <- (annotation$SUB_PATHWAY %in% c(mito_subpaths, lipid_subpaths, fa_subpaths, bile_subpaths, steroid_subpaths, purine_subpaths)) | grepl(base_keywords, annotation$CHEMICAL_NAME, ignore.case = TRUE)
priority_names <- c("serotonin", "5-HIAA", "tryptophan", "tryptamine", "melatonin", "dopamine", "dopac", "3,4-dihydroxyphenylacetate", "homovanillate", "homovanillic acid", "3-methoxytyramine", "norepinephrine", "noradrenaline", "epinephrine", "adrenaline", "metanephrine", "normetanephrine", "vanillylmandelate", "VMA", "glutamate", "glutamine", "GABA", "gamma-aminobutyrate", "acetylcholine", "choline", "histamine", "histidine")
match_idx <- rep(FALSE, nrow(annotation))
for (p_low in tolower(priority_names)) { match_idx <- match_idx | (tolower(annotation$CHEMICAL_NAME) == p_low) | grepl(paste0("\\b", gsub(" ", "\\\\s+", p_low), "\\b"), tolower(annotation$CHEMICAL_NAME)) }

v12_target_ids <- c(as.character(annotation$CHEM_ID[annotation$PTSDBioPriority_v8 | match_idx]), "GABR", "Glycolytic_Ratio")
mat_final <- mat_final[rownames(mat_final) %in% v12_target_ids, ]

# ----------------------------------------------------
# Define Target Subtypes Group
# ----------------------------------------------------
meta_sub <- metadata_final %>%
  mutate(
    Group_Sub = case_when(
      PTSD_status_binary == "Control" ~ "Control",
      four_subtypes == "Depressive Symptom Subtype" ~ "Depressive",
      four_subtypes == "Impaired Cognitive Function" ~ "Cognitive",
      four_subtypes == "Subthreshold/Mild PTSD Subtype" ~ "MildPTSD",
      TRUE ~ NA_character_
    )
  ) %>% filter(!is.na(Group_Sub))

mat_sub <- mat_final[, meta_sub$Metabolon_ID]
Groups <- factor(meta_sub$Group_Sub)
levels(Groups) <- make.names(levels(Groups))

contrasts_eval <- c("Depressive - Control", "Cognitive - Control", "MildPTSD - Control")
results_summary <- data.frame(Model=character(), Contrast=character(), P01_Yield=integer(), stringsAsFactors=FALSE)

cat("Running AutoResearch Benchmark on", nrow(mat_final), "V12 Biomarkers...\n")

# Helper function to append results
append_res <- function(model_name, contrast, p01_count) {
  results_summary <<- rbind(results_summary, data.frame(Model=model_name, Contrast=contrast, P01_Yield=p01_count))
}

# ----------------------------------------------------
# BASE MODEL (0): Standard heavy GLM
# ----------------------------------------------------
design0 <- model.matrix(~0 + Groups + Age + Gender + BMI + Cohort, data = meta_sub)
colnames(design0)[1:nlevels(Groups)] <- levels(Groups)
fit0 <- contrasts.fit(lmFit(mat_sub, design0), makeContrasts(contrasts=contrasts_eval, levels=design0))
fit0 <- eBayes(fit0)
for(c_name in contrasts_eval) append_res("Model 0: Base GLM Matrix", c_name, sum(topTable(fit0, coef=c_name, n=Inf)$P.Value < 0.01))

# ----------------------------------------------------
# MODEL 1: SPARSE MODEL (Drop BMI, Cohort, Age)
# ----------------------------------------------------
design1 <- model.matrix(~0 + Groups + Gender, data = meta_sub)
colnames(design1)[1:nlevels(Groups)] <- levels(Groups)
fit1 <- contrasts.fit(lmFit(mat_sub, design1), makeContrasts(contrasts=contrasts_eval, levels=design1))
fit1 <- eBayes(fit1)
for(c_name in contrasts_eval) append_res("Model 1: Sparse (Less Covariates)", c_name, sum(topTable(fit1, coef=c_name, n=Inf)$P.Value < 0.01))

# ----------------------------------------------------
# MODEL 2: ROBUST EMPIRICAL BAYES (Outlier Squeezing)
# ----------------------------------------------------
fit2 <- contrasts.fit(lmFit(mat_sub, design0, method="robust"), makeContrasts(contrasts=contrasts_eval, levels=design0))
fit2 <- eBayes(fit2, robust=TRUE)
for(c_name in contrasts_eval) append_res("Model 2: Robust eBayes", c_name, sum(topTable(fit2, coef=c_name, n=Inf)$P.Value < 0.01))

# ----------------------------------------------------
# MODEL 3: SVA LATENT DENOISING (Control batch effects)
# ----------------------------------------------------
mod3 <- model.matrix(~Groups + Age + Gender + BMI, data = meta_sub)
mod0 <- model.matrix(~1 + Age + Gender + BMI, data = meta_sub)
svobj <- tryCatch({
  sva(mat_sub, mod3, mod0, n.sv=2)
}, error = function(e) { NULL })

if(!is.null(svobj)){
  meta_sub$SV1 <- svobj$sv[,1]
  meta_sub$SV2 <- svobj$sv[,2]
  design3 <- model.matrix(~0 + Groups + Age + Gender + BMI + SV1 + SV2, data = meta_sub)
  colnames(design3)[1:nlevels(Groups)] <- levels(Groups)
  fit3 <- contrasts.fit(lmFit(mat_sub, design3), makeContrasts(contrasts=contrasts_eval, levels=design3))
  fit3 <- eBayes(fit3)
  for(c_name in contrasts_eval) append_res("Model 3: SVA Latent Denoising", c_name, sum(topTable(fit3, coef=c_name, n=Inf)$P.Value < 0.01))
}

# ----------------------------------------------------
# MODEL 4: QUANTILE NORMALIZATION (Distribution Forcing)
# ----------------------------------------------------
mat_norm <- normalizeBetweenArrays(mat_sub, method="quantile")
fit4 <- contrasts.fit(lmFit(mat_norm, design0), makeContrasts(contrasts=contrasts_eval, levels=design0))
fit4 <- eBayes(fit4)
for(c_name in contrasts_eval) append_res("Model 4: Quantile Normalized", c_name, sum(topTable(fit4, coef=c_name, n=Inf)$P.Value < 0.01))

# ----------------------------------------------------
# MODEL 5: IPW (Inverse Probability Weighting)
# ----------------------------------------------------
# Natively Limma accepts sample-specific weights. Weighting requires binary contrast isolation for clean propensity scaling.
for(c_name in contrasts_eval) {
    target_group <- gsub(" - Control", "", c_name)
    sub_idx <- meta_sub$Group_Sub %in% c("Control", target_group)
    meta_ipw <- meta_sub[sub_idx, ]
    mat_ipw <- mat_sub[, sub_idx]
    
    # Simple logistic propensity model
    ps_mod <- glm(Group_Sub != "Control" ~ Age + Gender + BMI + Cohort, data = meta_ipw, family=binomial)
    meta_ipw$PS <- predict(ps_mod, type="response")
    
    # Calculate IPW weights (stabilized)
    meta_ipw <- meta_ipw %>% mutate(
        w = ifelse(Group_Sub != "Control", mean(Group_Sub != "Control")/PS, mean(Group_Sub == "Control")/(1-PS)),
        w = pmin(pmax(w, 0.1), 10)  # Robust clipping
    )
    
    # IPW Limma Run
    Groups_ipw <- factor(meta_ipw$Group_Sub)
    levels(Groups_ipw) <- make.names(levels(Groups_ipw))
    design_ipw <- model.matrix(~0 + Groups_ipw, data=meta_ipw)
    colnames(design_ipw)[1:nlevels(Groups_ipw)] <- levels(Groups_ipw)
    
    fit5 <- contrasts.fit(lmFit(mat_ipw, design_ipw, weights=meta_ipw$w), makeContrasts(contrasts=c(c_name), levels=design_ipw))
    fit5 <- eBayes(fit5)
    append_res("Model 5: IPW Randomization", c_name, sum(topTable(fit5, coef=1, n=Inf)$P.Value < 0.01))
}

# ----------------------------------------------------
# Print Output Map
# ----------------------------------------------------
library(tidyr)
res_wide <- results_summary %>% pivot_wider(names_from = Contrast, values_from = P01_Yield)
write.csv(res_wide, "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/result_V12/AutoResearch_Yield.csv", row.names=F)
print(res_wide)
