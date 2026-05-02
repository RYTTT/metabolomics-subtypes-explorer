library(readxl)
library(dplyr)
library(limma)
library(randomForest)

options(stringsAsFactors = FALSE)
cat("Deploying First-Principles Biological Architecture...\n")

working_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/"
file_name <- "Bridged metabolomics data_subtype analysis_2026.4.22_NEW CONTROLS-2.xlsx"
input_path <- file.path(working_dir, "Meta subtype  Antigravity", "resource", file_name)
out_dir <- file.path(working_dir, "Meta subtype  Antigravity", "result_Causal", "First_Principles")
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

# ----------------------------------------------------
# PRINCIPLE I: Orthogonal Internal PTSD Baseline (Drop all Controls)
# ----------------------------------------------------
keep_ids <- m_meta %>% filter(!is.na(PTSD_status_binary) & PTSD_status_binary == "PTSD") %>% pull(Metabolon_ID)
m_meta <- m_meta %>% filter(Metabolon_ID %in% keep_ids)
mat <- mat[, m_meta$Metabolon_ID]

cat(paste("Isolated Pure Trauma Matrix:", ncol(mat), "Subjects.\n"))

# Target Lists
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

targets <- as.character(annotation$CHEM_ID[v8 | v12])
mat <- mat[rownames(mat) %in% targets, ]

# ----------------------------------------------------
# PRINCIPLE IV: Algorithmic Stoichiometry
# ----------------------------------------------------
cat("Calculating empirical stoichiometric indices...\n")
unlog <- function(x) 2^x 

# Extract priority array identifiers detected in the target slice
neuro_ids <- as.character(annotation$CHEM_ID[v12])
neuro_ids <- neuro_ids[neuro_ids %in% rownames(mat)]

# Calculate pairwise Log-Ratios systematically for highly central neuro-elements
# This mimics actual biochemical conversion rates (e.g. enzymatic kinetics) rather than raw concentration pools.
ratio_list <- list()
for(i in 1:(length(neuro_ids)-1)) {
    for(j in (i+1):length(neuro_ids)) {
        id1 <- neuro_ids[i]
        id2 <- neuro_ids[j]
        nm1 <- annotation$CHEMICAL_NAME[annotation$CHEM_ID == id1][1]
        nm2 <- annotation$CHEMICAL_NAME[annotation$CHEM_ID == id2][1]
        ratio_name <- substr(paste0(nm1, "_to_", nm2), 1, 64)
        ratio_name <- make.names(ratio_name)
        
        # Calculate ratio: Log2( Unlog(X) / Unlog(Y) )
        r_val <- log2(unlog(mat[id1,]) / unlog(mat[id2,]))
        ratio_list[[ratio_name]] <- r_val
    }
}
mat_ratios <- do.call(rbind, ratio_list)
mat <- rbind(mat, mat_ratios)

cat(paste("Generated Total Nodes (Raw V12 + Stoichiometric Ratios):", nrow(mat), "\n"))

# ----------------------------------------------------
# Causal Execution
# ----------------------------------------------------
set.seed(42)
m_meta <- m_meta %>% mutate(Group_Sub = case_when(four_subtypes=="Depressive Symptom Subtype"~"Depressive", four_subtypes=="Impaired Cognitive Function"~"Cognitive", four_subtypes=="Subthreshold/Mild PTSD Subtype"~"MildPTSD", four_subtypes=="Moderate/Severe PTSD Subtype"~"SeverePTSD", TRUE~NA_character_))

m_meta <- m_meta %>% filter(!is.na(Group_Sub))
mat <- mat[, m_meta$Metabolon_ID]

for(tgt in c("Depressive", "Cognitive")) {
  sub_m <- m_meta
  sub_mat <- mat
  
  # Principle I: Case vs All Remaining PTSD
  sub_m$IsCase <- ifelse(sub_m$Group_Sub == tgt, 1, 0)
  
  # Causal Inference Array (TMLE-Approx/RF-IPW) applied on orthogonal contrast
  rf <- randomForest(as.factor(IsCase) ~ Age + Gender + BMI + Cohort, data=sub_m, ntree=200)
  sub_m$RF_PS <- predict(rf, type="prob")[,2]
  sub_m$RF_PS <- pmax(pmin(sub_m$RF_PS, 0.95), 0.05)
  marg <- mean(sub_m$IsCase)
  sub_m$w <- ifelse(sub_m$IsCase==1, marg/sub_m$RF_PS, (1-marg)/(1-sub_m$RF_PS))
  
  dsn <- model.matrix(~IsCase + Age + Gender + BMI + Cohort, data=sub_m)
  
  fit <- eBayes(lmFit(sub_mat, dsn, weights=sub_m$w), robust=TRUE, trend=TRUE)
  res <- topTable(fit, coef="IsCase", n=Inf, sort.by="P")
  
  res$CHEM_ID <- rownames(res); res$Original_ID <- res$CHEM_ID; res$CHEM_ID <- suppressWarnings(as.numeric(res$CHEM_ID))
  res_out <- left_join(res, annotation, by="CHEM_ID")
  
  # Inject Names for Ratios correctly
  res_out$CHEMICAL_NAME <- ifelse(is.na(res_out$CHEMICAL_NAME), res_out$Original_ID, res_out$CHEMICAL_NAME)
  res_out$SUB_PATHWAY <- ifelse(is.na(res_out$SUB_PATHWAY) & grepl("_to_", res_out$CHEMICAL_NAME), "Stoichiometry / Network Ratio", res_out$SUB_PATHWAY)
  
  write.csv(res_out, file.path(out_dir, paste0("Orthogonal_", tgt, "_vs_InternalPTSD.csv")), row.names=FALSE)
}
cat("First Principles Pipeline execution completed successfully. Matrices published to disk.\n")
