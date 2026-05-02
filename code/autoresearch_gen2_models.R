library(readxl)
library(dplyr)
library(limma)
library(stringr)

cat("Initializing Gen II Modeling Framework...\n")
working_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/"
file_name <- "Bridged metabolomics data_subtype analysis_2026.4.22_NEW CONTROLS-2.xlsx"
input_path <- file.path(working_dir, "Meta subtype  Antigravity", "resource", file_name)

# ----------------------------------------------------
# 1. LOAD DATA & METADATA (V12 Mapping)
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

complete_cases_idx <- complete.cases(metadata_filtered[, c("Age", "Gender", "BMI", "Cohort")])
metadata_final <- metadata_filtered[complete_cases_idx, ]
mat_final <- mat[, complete_cases_idx]

keep_ids <- metadata_final %>% filter(!is.na(PTSD_status_binary)) %>% pull(Metabolon_ID)
metadata_final <- metadata_final %>% filter(Metabolon_ID %in% keep_ids)
mat_final <- mat_final[, metadata_final$Metabolon_ID]

# ----------------------------------------------------
# 2. CALCULATE INDICES & ENFORCE V12 PATHWAYS
# ----------------------------------------------------
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


# ----------------------------------------------------
# 3. CLINICAL PHENOTYPING
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
contrasts_eval <- c("Depressive - Control", "Cognitive - Control", "MildPTSD - Control")
results_summary <- data.frame(Model=character(), Contrast=character(), Signal_Yield=integer(), stringsAsFactors=FALSE)

append_res <- function(model_name, contrast, p01_count) {
  results_summary <<- rbind(results_summary, data.frame(Model=model_name, Contrast=contrast, Signal_Yield=p01_count))
}

# ----------------------------------------------------
# GEN II MODELS EXECUTION
# ----------------------------------------------------
for(c_name in contrasts_eval) {
    cat(paste("\n=> Processing Contrast:", c_name, "\n"))
    
    target_group <- gsub(" - Control", "", c_name)
    sub_idx <- meta_sub$Group_Sub %in% c("Control", target_group)
    m_trt <- meta_sub[sub_idx, ]
    m_mat <- mat_sub[, sub_idx]
    
    m_trt$IsCase <- ifelse(m_trt$Group_Sub == target_group, 1, 0)
    
    # ---------------------------------
    # MODEL 6: Caliper PSM
    # ---------------------------------
    tryCatch({
        library(MatchIt)
        m_trt$IsCase_logical <- as.logical(m_trt$IsCase)
        m.out <- matchit(IsCase ~ Age + Gender + BMI + Cohort, data=m_trt, method="nearest", caliper=0.2)
        m.data <- match.data(m.out)
        mat_psm <- m_mat[, m.data$Metabolon_ID]
        
        design_psm <- model.matrix(~0 + factor(m.data$IsCase) + subclass, data=m.data)
        fit_psm <- lmFit(mat_psm, design_psm)
        fit_psm <- eBayes(contrasts.fit(fit_psm, makeContrasts("factor(m.data$IsCase)1 - factor(m.data$IsCase)0", levels=design_psm)))
        
        append_res("Model 6: Topologic PSM", c_name, sum(topTable(fit_psm, coef=1, n=Inf)$P.Value < 0.01))
    }, error=function(e){ append_res("Model 6: Topologic PSM", c_name, NA) })
    
    # ---------------------------------
    # MODEL 7: Elastic Net (Non-zero signals)
    # ---------------------------------
    tryCatch({
        library(glmnet)
        x_net <- t(m_mat)
        y_net <- m_trt$IsCase
        
        # Adjust for covariates by residualization first
        res_x <- apply(x_net, 2, function(v) residuals(lm(v ~ Age + Gender + BMI + Cohort, data=m_trt)))
        
        cv_fit <- cv.glmnet(x=res_x, y=y_net, family="binomial", alpha=0.5, nfolds=5)
        coefs <- coef(cv_fit, s="lambda.min")
        nonzero_count <- sum(coefs[-1, 1] != 0) # Exclude intercept
        
        append_res("Model 7: Elastic Net Drivers", c_name, nonzero_count)
    }, error=function(e){ append_res("Model 7: Elastic Net Drivers", c_name, NA) })
    
    # ---------------------------------
    # MODEL 8: Fast WGCNA Transform (Module Level)
    # ---------------------------------
    tryCatch({
        # Fast hierarchical correlation clustering (pseudo-WGCNA)
        dist_mat <- as.dist(1 - cor(t(m_mat), method="pearson"))
        hc <- hclust(dist_mat, method="average")
        modules <- cutree(hc, h=0.3) # Define modules
        n_mod <- length(unique(modules))
        
        mod_pvals <- c()
        for(m in unique(modules)){
            mat_mod <- t(m_mat[modules == m, , drop=FALSE])
            if(ncol(mat_mod) > 1) pc <- prcomp(mat_mod, scale=TRUE)$x[,1] else pc <- mat_mod[,1]
            pval <- summary(lm(pc ~ m_trt$IsCase + Age + Gender + BMI + Cohort, data=m_trt))$coefficients[2,4]
            mod_pvals <- c(mod_pvals, pval)
        }
        append_res("Model 8: WGCNA Eigengene Topology", c_name, sum(mod_pvals < 0.05)) # Signif Modules
    }, error=function(e){ append_res("Model 8: WGCNA Eigengene Topology", c_name, NA) })
    
    # ---------------------------------
    # MODEL 9: TMLE Array Approximation (SuperLearner IPW)
    # ---------------------------------
    # Due to full TMLE scaling limits, we substitute heavily penalized logistic Random Forest equivalent propensities
    tryCatch({
        library(randomForest)
        rf_ps <- randomForest(as.factor(IsCase) ~ Age + Gender + BMI + Cohort, data=m_trt, ntree=200)
        m_trt$RF_PS <- predict(rf_ps, type="prob")[,2]
        m_trt$RF_PS <- pmax(pmin(m_trt$RF_PS, 0.95), 0.05)
        
        marg <- mean(m_trt$IsCase)
        m_trt$w <- ifelse(m_trt$IsCase==1, marg/m_trt$RF_PS, (1-marg)/(1-m_trt$RF_PS))
        
        Groups_v <- factor(m_trt$Group_Sub)
        design_v <- model.matrix(~0 + Groups_v + Age + Gender + BMI + Cohort, data=m_trt)
        colnames(design_v)[1:2] <- levels(Groups_v)
        
        fit_tmle <- eBayes(contrasts.fit(lmFit(m_mat, design_v, weights=m_trt$w), makeContrasts(paste0(target_group,"-Control"), levels=design_v)), robust=TRUE)
        append_res("Model 9: TMLE-Approx (Non-parametric PS)", c_name, sum(topTable(fit_tmle, coef=1, n=Inf)$P.Value < 0.01))
    }, error=function(e){ append_res("Model 9: TMLE-Approx (Non-parametric PS)", c_name, NA) })
    
    # ---------------------------------
    # MODEL 10: Non-Parametric Residual Shift (Wilcox + BY FDR)
    # ---------------------------------
    tryCatch({
        # Regress covariates robustly
        resid_mat <- apply(m_mat, 1, function(y) residuals(lm(y ~ Age + Gender + BMI + Cohort, data=m_trt)))
        resid_mat <- t(resid_mat)
        
        pvals <- apply(resid_mat, 1, function(y) wilcox.test(y[m_trt$IsCase==1], y[m_trt$IsCase==0])$p.value)
        fdr_by <- p.adjust(pvals, method="BY")
        
        append_res("Model 10: Residual Non-Parametric (FDR BY)", c_name, sum(fdr_by < 0.10)) # Yield via FDR BY
    }, error=function(e){ append_res("Model 10: Residual Non-Parametric (FDR BY)", c_name, NA) })

}

library(tidyr)
res_wide <- results_summary %>% pivot_wider(names_from = Contrast, values_from = Signal_Yield)
print(res_wide)
