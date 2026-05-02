library(readxl)
library(dplyr)
library(limma)

options(stringsAsFactors = FALSE)
cat("Deploying Generation III Defensible Causal Baseline...\n")

working_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/"
file_name <- "Bridged metabolomics data_subtype analysis_2026.4.22_NEW CONTROLS-2.xlsx"
input_path <- file.path(working_dir, "Meta subtype  Antigravity", "resource", file_name)
out_dir <- file.path(working_dir, "Meta subtype  Antigravity", "result_Causal", "Gen3_Metrics")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

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
idx <- complete.cases(m_meta[, c("Age", "Gender", "BMI", "Cohort")])
m_meta <- m_meta[idx,]
mat <- mat[, idx]

keep_ids <- m_meta %>% filter(!is.na(PTSD_status_binary)) %>% pull(Metabolon_ID)
m_meta <- m_meta %>% filter(Metabolon_ID %in% keep_ids)
mat <- mat[, m_meta$Metabolon_ID]

# V12 Filter
priority <- c("serotonin", "5-HIAA", "tryptophan", "tryptamine", "melatonin", "dopamine", "dopac", "3,4-dihydroxyphenylacetate", "homovanillate", "homovanillic acid", "3-methoxytyramine", "norepinephrine", "noradrenaline", "epinephrine", "adrenaline", "metanephrine", "normetanephrine", "vanillylmandelate", "VMA", "glutamate", "glutamine", "GABA", "gamma-aminobutyrate", "acetylcholine", "choline", "histamine", "histidine")
v12 <- rep(FALSE, nrow(annotation))
for(p in priority) v12 <- v12 | grepl(paste0("\\b",p,"\\b"), annotation$CHEMICAL_NAME, ignore.case=TRUE)
mat <- mat[rownames(mat) %in% as.character(annotation$CHEM_ID[v12]), ]

m_meta <- m_meta %>% mutate(Group_Sub = case_when(PTSD_status_binary=="Control"~"Control", four_subtypes=="Depressive Symptom Subtype"~"Depressive", four_subtypes=="Impaired Cognitive Function"~"Cognitive", four_subtypes=="Subthreshold/Mild PTSD Subtype"~"MildPTSD", four_subtypes=="Moderate/Severe PTSD Subtype"~"SeverePTSD", TRUE~NA_character_))
m_meta <- m_meta %>% filter(!is.na(Group_Sub))
mat <- mat[, m_meta$Metabolon_ID]


contrasts_eval <- c("Depressive - Control", "Cognitive - Control", "MildPTSD - Control")
results_summary <- data.frame(Model=character(), Contrast=character(), Signal_Yield=integer(), stringsAsFactors=FALSE)

append_res <- function(model_name, contrast, p01_count) {
  results_summary <<- rbind(results_summary, data.frame(Model=model_name, Contrast=contrast, Signal_Yield=p01_count))
}

for(c_name in contrasts_eval) {
    cat(paste("\n=> Generating Defensible Metrics for:", c_name, "\n"))
    
    tgt <- gsub(" - Control", "", c_name)
    sub_m <- m_meta %>% filter(Group_Sub %in% c("Control", tgt))
    sub_mat <- mat[, sub_m$Metabolon_ID]
    sub_m$IsCase <- ifelse(sub_m$Group_Sub == tgt, 1, 0)
    
    # ---------------------------------
    # MODEL 11: Z-Score Clinical Extreme Mapping (Fisher's Exact)
    # ---------------------------------
    tryCatch({
      c_idx <- sub_m$IsCase == 0
      t_idx <- sub_m$IsCase == 1
      means <- rowMeans(sub_mat[, c_idx, drop=FALSE])
      sds <- apply(sub_mat[, c_idx, drop=FALSE], 1, sd)
      z_mat <- sweep(sub_mat, 1, means, "-")
      z_mat <- sweep(z_mat, 1, sds, "/")
      
      fish_p <- apply(z_mat, 1, function(row) {
        c_extremes <- sum(abs(row[c_idx]) > 2)
        c_norm <- sum(abs(row[c_idx]) <= 2)
        t_extremes <- sum(abs(row[t_idx]) > 2)
        t_norm <- sum(abs(row[t_idx]) <= 2)
        m <- matrix(c(c_extremes, c_norm, t_extremes, t_norm), nrow=2)
        tryCatch(fisher.test(m)$p.value, error=function(e) 1)
      })
      append_res("Model 11: Z-Score Proportion Maps", c_name, sum(fish_p < 0.05))
    }, error=function(e) { append_res("Model 11: Z-Score Proportion Maps", c_name, NA) })
    
    # ---------------------------------
    # MODEL 12: Supervised PLS-DA VIP scores
    # ---------------------------------
    tryCatch({
      library(pls)
      plsr_mod <- plsr(sub_m$IsCase ~ t(sub_mat), ncomp=3, scale=TRUE, validation="none")
      
      VIP <- function(object) {
        if(nrow(object$Yloadings) > 1) stop("Only implemented for single-response models")
        SS <- c(object$Yloadings)^2 * colSums(object$scores^2)
        Wnorm2 <- colSums(object$loading.weights^2)
        SSW <- sweep(object$loading.weights^2, 2, SS / Wnorm2, "*")
        VIPs <- sqrt(nrow(SSW) * apply(SSW, 1, cumsum) / cumsum(SS))
        return(matrix(VIPs, ncol=ncol(VIPs)))
      }
      
      vips <- VIP(plsr_mod)[3, ] # extract component 3
      append_res("Model 12: Sparse PLS-DA VIP > 1.5", c_name, sum(vips > 1.5))
    }, error=function(e) { append_res("Model 12: Sparse PLS-DA VIP > 1.5", c_name, NA) })
    
    # ---------------------------------
    # MODEL 13: Boruta Feature Selection
    # ---------------------------------
    tryCatch({
      library(Boruta)
      set.seed(42)
      df_b <- as.data.frame(t(sub_mat))
      df_b$Target <- factor(sub_m$IsCase)
      b_res <- Boruta(Target ~ ., data=df_b, doTrace=0, maxRuns=100)
      sel <- getSelectedAttributes(b_res, withTentative = FALSE)
      append_res("Model 13: Boruta Consensus Drivers", c_name, length(sel))
    }, error=function(e) { append_res("Model 13: Boruta Consensus Drivers", c_name, NA) })
    
    # ---------------------------------
    # MODEL 14: Ordinal Pathological Escalation
    # ---------------------------------
    tryCatch({
      # Uses the full m_meta dataset
      ord_meta <- m_meta %>% filter(Group_Sub %in% c("Control", "MildPTSD", tgt, "SeverePTSD")) %>% 
        mutate(ord_score = case_when(Group_Sub == "Control" ~ 0, Group_Sub == "MildPTSD" ~ 1, Group_Sub == tgt ~ 2, Group_Sub == "SeverePTSD" ~ 3))
      ord_mat <- mat[, ord_meta$Metabolon_ID]
      
      ord_p <- apply(ord_mat, 1, function(y) {
        summary(lm(y ~ ord_score + Age + Gender + BMI + Cohort, data=ord_meta))$coefficients["ord_score", 4]
      })
      append_res("Model 14: Ordinal Severity Escalation", c_name, sum(ord_p < 0.01))
    }, error=function(e) { append_res("Model 14: Ordinal Severity Escalation", c_name, NA) })
    
    # ---------------------------------
    # MODEL 15: Exact Consensus Bootstrapping  
    # ---------------------------------
    tryCatch({
      set.seed(99)
      n_tgt <- sum(sub_m$IsCase == 1)
      idx_tgt <- which(sub_m$IsCase == 1)
      idx_ctrl <- which(sub_m$IsCase == 0)
      
      hit_counts <- rep(0, nrow(sub_mat))
      for(b in 1:100) {
        sample_c <- sample(idx_ctrl, n_tgt, replace=FALSE)
        boot_idx <- c(idx_tgt, sample_c)
        boot_m <- sub_m[boot_idx, ]
        boot_mat <- sub_mat[, boot_idx]
        
        G <- factor(boot_m$IsCase)
        design_b <- model.matrix(~G + Age + Gender + BMI + Cohort, data=boot_m)
        fit_b <- eBayes(lmFit(boot_mat, design_b))
        pvals <- topTable(fit_b, coef=2, n=Inf, sort.by="none")$P.Value
        
        # In limma, sort.by="none" keeps rows in original order
        hit_counts <- hit_counts + (pvals < 0.05)
      }
      append_res("Model 15: Exact Match Bootstrapping (>85% Consensus)", c_name, sum(hit_counts >= 85))
    }, error=function(e) { append_res("Model 15: Exact Match Bootstrapping (>85% Consensus)", c_name, NA) })
}

library(tidyr)
res_wide <- results_summary %>% pivot_wider(names_from = Contrast, values_from = Signal_Yield)
print(res_wide)
cat("Gen III Algorithms Evaluated Natively.\n")
