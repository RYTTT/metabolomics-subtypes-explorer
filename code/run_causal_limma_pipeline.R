library(readxl)
library(dplyr)
library(limma)
library(stringr)

options(stringsAsFactors = FALSE)

working_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/"
file_name <- "Bridged metabolomics data_subtype analysis_2026.4.22_NEW CONTROLS-2.xlsx"
input_path <- file.path(working_dir, "Meta subtype  Antigravity", "resource", file_name)
out_dir <- file.path(working_dir, "Meta subtype  Antigravity", "result_Causal")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ----------------------------------------------------
# 1. LOAD DATA & METADATA (V12 Mapping)
# ----------------------------------------------------
cat("Loading data matrices and covariates...\n")
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

complete_cases_idx <- complete.cases(metadata_filtered[, c("Age", "Gender", "BMI", "Cohort")])
metadata_final <- metadata_filtered[complete_cases_idx, ]
mat_final <- mat[, complete_cases_idx]

# Drop removed controls
keep_ids <- metadata_final %>% filter(!is.na(PTSD_status_binary)) %>% pull(Metabolon_ID)
metadata_final <- metadata_final %>% filter(Metabolon_ID %in% keep_ids)
mat_final <- mat_final[, metadata_final$Metabolon_ID]

cat(paste("Analyzed Observational Geometry:", nrow(metadata_final), "Samples \n"))

# ----------------------------------------------------
# 2. CALCULATE INDICES & ENFORCE V12 PATHWAYS
# ----------------------------------------------------
cat("Deriving target matrices and biological logic...\n")
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
cat(paste("Filtered Output:", nrow(mat_final), "Features \n"))

# ----------------------------------------------------
# 3. CLINICAL PHENOTYPING
# ----------------------------------------------------
meta_obs <- metadata_final %>%
  mutate(
    Group_Sub = case_when(
      PTSD_status_binary == "Control" ~ "Control",
      four_subtypes == "Depressive Symptom Subtype" ~ "Depressive",
      four_subtypes == "Impaired Cognitive Function" ~ "Cognitive",
      four_subtypes == "Subthreshold/Mild PTSD Subtype" ~ "MildPTSD",
      four_subtypes == "Moderate/Severe PTSD Subtype" ~ "SeverePTSD",
      TRUE ~ NA_character_
    )
  ) %>% filter(!is.na(Group_Sub))

mat_obs <- mat_final[, meta_obs$Metabolon_ID]
contrasts_eval <- c("Depressive", "Cognitive", "MildPTSD", "SeverePTSD")

# ----------------------------------------------------
# 4. DOUBLY ROBUST S-IPW PIPELINE
# ----------------------------------------------------
cat("\nExecuting Causal Inference Workflows...\n")

for(trt_label in contrasts_eval) {
    cat(paste(">>> Fitting Target Contrast:", trt_label, "vs Control\n"))
    
    # Isolate strictly binary pairs to ensure valid structural propensity scores
    sub_idx <- meta_obs$Group_Sub %in% c("Control", trt_label)
    meta_trt <- meta_obs[sub_idx, ]
    mat_trt <- mat_obs[, sub_idx]
    
    # Binary response definition
    meta_trt$IsCase <- ifelse(meta_trt$Group_Sub == trt_label, 1, 0)
    
    # Fit Propensity Score via GLM using structured covariates
    ps_model <- glm(IsCase ~ Age + Gender + BMI + Cohort, data = meta_trt, family = binomial)
    meta_trt$PS <- predict(ps_model, type="response")
    
    # Calculate Marginal Trajectory
    marginal_trt <- mean(meta_trt$IsCase == 1)
    marginal_ctrl <- mean(meta_trt$IsCase == 0)
    
    # Produce Stabilized Weights (SW)
    meta_trt <- meta_trt %>% mutate(
        Stabilized_Weight = ifelse(IsCase == 1, marginal_trt / PS, marginal_ctrl / (1 - PS))
    )
    
    # Truncate Extrema at 5th and 95th Percentiles (Protects Bayes Variance)
    q05 <- quantile(meta_trt$Stabilized_Weight, 0.05)
    q95 <- quantile(meta_trt$Stabilized_Weight, 0.95)
    meta_trt <- meta_trt %>% mutate(
        Truncated_Weight = pmin(pmax(Stabilized_Weight, q05), q95)
    )
    
    # Formulate Doubly Robust Design Matrix (including covariates)
    Groups_ipw <- factor(meta_trt$Group_Sub)
    levels(Groups_ipw) <- make.names(levels(Groups_ipw))
    design_dr <- model.matrix(~ 0 + Groups_ipw + Age + Gender + BMI + Cohort, data=meta_trt)
    colnames(design_dr)[1:2] <- levels(Groups_ipw)
    
    # Execute Linear Fit matching weights structurally
    fit_ipw <- lmFit(mat_trt, design_dr, weights = meta_trt$Truncated_Weight)
    
    # Make Contrast
    contrast_str <- paste0(make.names(trt_label), " - Control")
    contrast_matrix <- makeContrasts(contrasts = contrast_str, levels = design_dr)
    fit_cont <- contrasts.fit(fit_ipw, contrast_matrix)
    
    # Apply Robust Mean-Variance Empirical Bayes (Trend handling heteroscedasticity)
    fit_bayes <- eBayes(fit_cont, robust=TRUE, trend=TRUE)
    
    # Format and save output
    res <- topTable(fit_bayes, coef=1, number=Inf, sort.by="P")
    res$CHEM_ID <- rownames(res)
    res$Original_ID <- res$CHEM_ID
    res$CHEM_ID <- as.numeric(res$CHEM_ID)
    
    res_annotated <- left_join(res, annotation, by="CHEM_ID")
    res_annotated$CHEMICAL_NAME <- ifelse(is.na(res_annotated$CHEMICAL_NAME), res_annotated$Original_ID, res_annotated$CHEMICAL_NAME)
    
    filename <- file.path(out_dir, paste0("Causal_", trt_label, "_vs_Control.csv"))
    write.csv(res_annotated, filename, row.names=FALSE)
}

cat("\nPipeline Exited Generously. Results deposited in CAUSAL registry.\n")
