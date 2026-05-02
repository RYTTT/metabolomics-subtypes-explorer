library(readxl)
library(dplyr)
library(limma)
library(stringr)
library(tibble)

# --- Configuration ---
working_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/"
file_name <- "Bridged metabolomics data_subtype analysis_2026.4.22_NEW CONTROLS-2.xlsx"
input_path <- file.path(working_dir, "Meta subtype  Antigravity", "resource", file_name)
output_dir <- file.path(working_dir, "Meta subtype  Antigravity", "result_V12")

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# --- 1. Load Data ---
cat("Loading data...\n")

# Load Metabolomics Data
# Data is Samples (Rows) x Metabolites (Cols) based on inspection
metab_data <- read_excel(input_path, sheet = "LogGroup-norm Data Bridged wImp")

# Load Annotation (From the original V3 file since the new V3-2 drops this sheet)
annotation_path <- file.path(working_dir, "Bridged metabolomics data_subtype analysis_2025.12.18 V3.xlsx")
annotation <- read_excel(annotation_path, sheet = "annotation")

# Load ID Match & Status
status_df <- read_excel(input_path, sheet = "ID match & status")

# Load Demographics
demo_df <- read_excel(input_path, sheet = "demographics")

# --- 1b. Age Correction (EpiagePTSD) ---
# Check if EpiagePTSD.csv exists and use it to correct ages
epi_path <- file.path(working_dir, "EpiagePTSD.csv")
if (file.exists(epi_path)) {
  cat("\nLoading EpiagePTSD.csv for age correction...\n")
  epi_data <- read.csv(epi_path, row.names = 1)
  
  # Extract numeric ID from rownames (e.g., 201178R_N -> 201178)
  epi_data$Extracted_ID <- str_extract(rownames(epi_data), "^\\d+")
  
  # Check for valid IDs
  epi_data <- epi_data[!is.na(epi_data$Extracted_ID), ]
  
  # Aggregate Age by ID (mean) to handle duplicates
  epi_ages <- epi_data %>%
    group_by(Extracted_ID) %>%
    summarize(Corrected_Age = mean(Age, na.rm = TRUE))
    
  # Update Demographics
  # Convert ID to character for joining
  demo_df <- demo_df %>% mutate(ID_char = as.character(ID))
  
  # Join and update Age
  demo_df <- demo_df %>%
    left_join(epi_ages, by = c("ID_char" = "Extracted_ID")) %>%
    mutate(
      Original_Age = Age,
      Age = ifelse(!is.na(Corrected_Age), Corrected_Age, Age)
    )
  
  # Report changes
  changed_count <- sum(demo_df$Age != demo_df$Original_Age, na.rm = TRUE)
  cat(paste("Updated Age for", changed_count, "subjects using EpiagePTSD.csv.\n"))
  
  # Clean up temporary columns
  demo_df <- demo_df %>% select(-ID_char, -Corrected_Age, -Original_Age)
  
} else {
  cat("\nWarning: EpiagePTSD.csv not found. Skipping age correction.\n")
}

# --- 1c. Manual Age Correction ---
# Manual corrections provided by user
manual_corrections <- data.frame(
  ID = c(202060, 202210, 211025, 211028, 212061),
  Manual_Age = c(30, 41, 31, 24, 29)
)

# Apply manual corrections
demo_df <- demo_df %>%
  left_join(manual_corrections, by = "ID") %>%
  mutate(
    Age = ifelse(!is.na(Manual_Age), Manual_Age, Age)
  ) %>%
  select(-Manual_Age)

cat(paste("Applied manual age corrections for", nrow(manual_corrections), "subjects.\n"))

# --- 1d. BMI Correction (allPTSDsamples) ---
# Update missing BMI in SBC cohort using allPTSDsamples 20170303.txt
ptsd_path <- file.path(working_dir, "allPTSDsamples 20170303.txt")
if (file.exists(ptsd_path)) {
  cat("\nLoading allPTSDsamples 20170303.txt for BMI correction...\n")
  ptsd_df <- read.delim(ptsd_path)
  
  # Extract numeric ID from Name (e.g., 201178R_N -> 201178)
  ptsd_df$Extracted_ID <- str_extract(ptsd_df$Name, "^\\d+")
  
  # Prepare BMI reference table (averaging duplicates if any)
  ptsd_bmi <- ptsd_df %>%
    filter(!is.na(BMI)) %>%
    group_by(Extracted_ID) %>%
    summarize(Corrected_BMI = mean(BMI, na.rm = TRUE))
  
  # Update Demographics
  demo_df <- demo_df %>% mutate(ID_char = as.character(ID))
  
  demo_df <- demo_df %>%
    left_join(ptsd_bmi, by = c("ID_char" = "Extracted_ID")) %>%
    mutate(
      Original_BMI = BMI,
      # Update BMI for ALL SBC subjects if available in ptsd file, otherwise keep original
      # For non-SBC cohorts, keep original (unless user wants all updated?)
      # User specified "update all subjects in SBC"
      BMI = ifelse(Cohort == "SBC" & !is.na(Corrected_BMI), Corrected_BMI, 
                   ifelse(is.na(BMI) & !is.na(Corrected_BMI), Corrected_BMI, BMI))
    )
    
  # Report changes
  bmi_changed_count <- sum(demo_df$BMI != demo_df$Original_BMI, na.rm = TRUE)
  cat(paste("Updated BMI for", bmi_changed_count, "SBC subjects using allPTSDsamples.\n"))
  
  # Clean up
  demo_df <- demo_df %>% select(-ID_char, -Corrected_BMI, -Original_BMI)

} else {
  cat("\nWarning: allPTSDsamples 20170303.txt not found. Skipping BMI correction.\n")
}

# --- 2. Data Preparation ---

# Prepare Metadata
# Merge Status and Demographics
# Status has Metabolon_ID, Demo has Metabolon_ID (and ID)
# Use Metabolon_ID as key since it matches Data's PARENT_SAMPLE_NAME

# First, align Demo and Status
# Check for duplicates
status_df <- status_df %>% distinct(Metabolon_ID, .keep_all = TRUE)
demo_df <- demo_df %>% distinct(Metabolon_ID, .keep_all = TRUE)

# Merge and Bridge New Column Structure
metadata <- full_join(status_df, demo_df, by = "Metabolon_ID") %>%
  mutate(
    # Translate the split columns back into the unitary logic expected by this script
    PTSD_status_binary = case_when(
      !is.na(`NEW Control group status`) & `NEW Control group status` == "Control" ~ "Control",
      !is.na(`OLD CATEGORY_PTSD_status_binary`) & `OLD CATEGORY_PTSD_status_binary` == "PTSD" ~ "PTSD",
      TRUE ~ NA_character_
    )
  )

# Ensure we have metadata for samples in the data
data_samples <- metab_data$PARENT_SAMPLE_NAME
metadata <- metadata %>% filter(Metabolon_ID %in% data_samples)

# Align Data with Metadata
# Filter data to only include samples present in metadata (and vice versa)
common_samples <- intersect(metab_data$PARENT_SAMPLE_NAME, metadata$Metabolon_ID)
cat(paste("Number of samples with both data and metadata:", length(common_samples), "\n"))

metab_data_filtered <- metab_data %>% filter(PARENT_SAMPLE_NAME %in% common_samples)
metadata_filtered <- metadata %>% filter(Metabolon_ID %in% common_samples)

# Sort both to ensure alignment
metab_data_filtered <- metab_data_filtered %>% arrange(PARENT_SAMPLE_NAME)
metadata_filtered <- metadata_filtered %>% arrange(Metabolon_ID)

if (!all(metab_data_filtered$PARENT_SAMPLE_NAME == metadata_filtered$Metabolon_ID)) {
  stop("Sample mismatch after alignment!")
}

# Prepare Matrix for Limma (Metabolites x Samples)
# Remove PARENT_SAMPLE_NAME column
mat <- as.matrix(metab_data_filtered %>% select(-PARENT_SAMPLE_NAME))
rownames(mat) <- metab_data_filtered$PARENT_SAMPLE_NAME
mat <- t(mat) # Transpose: Rows = Metabolites, Cols = Samples

# --- 3. Covariate Cleaning ---

# Clean covariates
metadata_filtered <- metadata_filtered %>%
  mutate(
    Age = as.numeric(Age),
    BMI = as.numeric(BMI),
    Gender = as.factor(Gender),
    Cohort = as.factor(Cohort) # Assuming 'Cohort' from demographics is relevant
  )

# Handle missing covariates if necessary (filtering out samples with NA in critical covariates)
# For this analysis, we will filter out samples with missing Age, Gender, or BMI to run the model correctly
complete_cases_idx <- complete.cases(metadata_filtered[, c("Age", "Gender", "BMI")])
cat(paste("Samples removed due to missing covariates:", sum(!complete_cases_idx), "\n"))

metadata_final <- metadata_filtered[complete_cases_idx, ]
mat_final <- mat[, complete_cases_idx]

# --- 2x. Bypass Control Downsampling ---
cat("\n--- Bypassing Propensity Matching (Using all new curated Controls) ---\n")

# Use everyone who now correctly has a PTSD_status_binary tag (dropping the 216 trimmed controls automatically)
keep_ids <- metadata_final %>%
  filter(!is.na(PTSD_status_binary)) %>%
  pull(Metabolon_ID)

cat(paste("Original Samples:", nrow(metadata_final), "\n"))
metadata_final <- metadata_final %>% filter(Metabolon_ID %in% keep_ids)
mat_final <- mat_final[, metadata_final$Metabolon_ID]
n_cases <- sum(metadata_final$PTSD_status_binary != "Control")
n_controls <- sum(metadata_final$PTSD_status_binary == "Control")
cat(paste("Matched Samples:", nrow(metadata_final), "(Cases:", n_cases, ", Controls:", n_controls, ")\n"))

# --- 2a/2b. Bypassing generic Lipid/Unknown Filters ---
cat("\n--- Bypassing standard lipid/unknown filters to apply unified V12 expert criteria ---\n")

# --- 2c. Calculate Custom Indices ---
# We need to find the specific metabolites to calculate the ratios
# GABR = Arginine / (Ornithine + Citrulline)
# Glycolytic ratio = (Lactate + Pyruvate) / Citrate

# Helper function to find closest matching metabolite name
find_metabolite <- function(keyword, available_names) {
  match <- grep(keyword, available_names, value = TRUE, ignore.case = TRUE)
  # Prefer exact match or simple match
  if (length(match) > 1) {
    # If multiple, look for exact match first
    exact <- match[tolower(match) == tolower(keyword)]
    if (length(exact) == 1) return(exact)
    return(match[1]) # Default to first if ambiguous
  }
  if (length(match) == 1) return(match)
  return(NULL)
}

# Get metabolite names from data columns (they were originally IDs, but let's check mapping)
# The mat_final has numeric Chem IDs as rownames. We need to map them to names first to find them,
# or map names to IDs.
# Annotation file has CHEM_ID and CHEMICAL_NAME

# Convert target names to IDs
find_id_by_name <- function(keyword, anno_df) {
  # keyword regex search in CHEMICAL_NAME
  hits <- anno_df[grep(paste0("^", keyword, "$"), anno_df$CHEMICAL_NAME, ignore.case = TRUE), ]
  if (nrow(hits) == 0) {
    # Try partial match if exact fails
    hits <- anno_df[grep(keyword, anno_df$CHEMICAL_NAME, ignore.case = TRUE), ]
  }
  
  if (nrow(hits) > 0) {
    # If multiple, take first (or warn)
    if (nrow(hits) > 1) {
       cat(paste("Multiple hits for", keyword, ":", paste(hits$CHEMICAL_NAME, collapse=", "), "- using", hits$CHEMICAL_NAME[1], "\n"))
    }
    return(hits$CHEM_ID[1])
  }
  return(NULL)
}

# Find IDs
id_arginine <- find_id_by_name("arginine", annotation)
id_ornithine <- find_id_by_name("ornithine", annotation)
id_citrulline <- find_id_by_name("citrulline", annotation)

id_lactate <- find_id_by_name("lactate", annotation)
id_pyruvate <- find_id_by_name("pyruvate", annotation)
id_citrate <- find_id_by_name("citrate", annotation)

cat("\n--- Custom Index Calculation ---\n")
cat(paste("Arginine ID:", id_arginine, "\n"))
cat(paste("Ornithine ID:", id_ornithine, "\n"))
cat(paste("Citrulline ID:", id_citrulline, "\n"))
cat(paste("Lactate ID:", id_lactate, "\n"))
cat(paste("Pyruvate ID:", id_pyruvate, "\n"))
cat(paste("Citrate ID:", id_citrate, "\n"))

# Calculate indices if IDs found
# mat_final rows are Metabolites (IDs), Cols are Samples
# Data is likely Log Transformed (sheet name "LogGroup-norm").
# Ratios in log scale: log(A/B) = log(A) - log(B)
# GABR = Arginine / (Ornithine + Citrulline)
# Log(GABR) = Log(Arginine) - Log(Ornithine + Citrulline)
# Wait, if data is already log transformed, we must unlog to sum (Ornithine + Citrulline) then log back?
# Or if approximation is okay. Usually "LogGroup-norm" implies data is log(x).
# X = exp(Data).
# Let's assume natural log or log2? Usually metabolon is base 2 or natural? 
# Usually better to calculate ratio on raw scale then log transform.
# Since we only have "LogGroup-norm", we will un-log (assume base 2 or e? Let's assume log base 2 is common in omics, or just exp if natural).
# Standard Metabolon is often imputed -> log transformed -> scaled.
# Let's treat values as Log2 for safety (standard in Limma).
# To sum (Ornithine + Citrulline), we need (2^Orn + 2^Cit).

# Function to get values for a row
get_vals <- function(id, matrix) {
  if (as.character(id) %in% rownames(matrix)) {
    return(matrix[as.character(id), ])
  }
  return(NULL)
}

# Vectorized Un-log (assuming log2, if it's natural log this will be slightly off scale but ratio logic holds)
# If unsure, check min/max.
unlog <- function(x) 2^x 

# Calculate GABR
# Formula: Arginine / (Ornithine + Citrulline)
vec_arg <- get_vals(id_arginine, mat_final)
vec_orn <- get_vals(id_ornithine, mat_final)
vec_cit <- get_vals(id_citrulline, mat_final)

if (!is.null(vec_arg) && !is.null(vec_orn) && !is.null(vec_cit)) {
  # Unlog to sum denominator
  denom <- unlog(vec_orn) + unlog(vec_cit)
  # Ratio
  raw_gabr <- unlog(vec_arg) / denom
  # Re-log for analysis
  log_gabr <- log2(raw_gabr)
  
  # Add to matrix
  mat_final <- rbind(mat_final, "GABR" = log_gabr)
  cat("Added GABR to matrix.\n")
} else {
  cat("Skipping GABR - missing metabolites.\n")
}

# Calculate Glycolytic Ratio
# Formula: (Lactate + Pyruvate) / Citrate
vec_lac <- get_vals(id_lactate, mat_final)
vec_pyr <- get_vals(id_pyruvate, mat_final)
vec_citr <- get_vals(id_citrate, mat_final)

if (!is.null(vec_lac) && !is.null(vec_pyr) && !is.null(vec_citr)) {
  # Unlog
  num <- unlog(vec_lac) + unlog(vec_pyr)
  # Ratio
  raw_glyc <- num / unlog(vec_citr)
  # Re-log
  log_glyc <- log2(raw_glyc)
  
  # Add to matrix
  mat_final <- rbind(mat_final, "Glycolytic_Ratio" = log_glyc)
  cat("Added Glycolytic_Ratio to matrix.\n")
} else {
  cat("Skipping Glycolytic_Ratio - missing metabolites.\n")
}

# --- 2d. Apply V12 Panel Filtering ---
cat("\n--- Applying V12 Targeted PTSD Panel Filter ---\n")

mito_subpaths <- c("Glycolysis, Gluconeogenesis, and Pyruvate Metabolism", "TCA Cycle", "Oxidative Phosphorylation", "Nicotinate and Nicotinamide Metabolism")
lipid_subpaths <- c("Ceramides", "Sphingomyelins", "Dihydrosphingomyelins", "Sphingosines", "Sphingolipid Synthesis", "Hexosylceramides (HCER)", "Lactosylceramides (LCER)", "Phosphatidylcholine (PC)", "Phosphatidylethanolamine (PE)", "Lysophospholipid", "Triacylglycerol")
fa_subpaths <- c("Carnitine Metabolism", "Ketone Bodies", "Long Chain Saturated Fatty Acid", "Long Chain Monounsaturated Fatty Acid", "Long Chain Polyunsaturated Fatty Acid (n3 and n6)", "Medium Chain Fatty Acid", "Short Chain Fatty Acid", "Fatty Acid Metabolism (Acyl Carnitine, Hydroxy)", "Fatty Acid Metabolism (Acyl Carnitine, Long Chain Saturated)", "Fatty Acid Metabolism (Acyl Carnitine, Medium Chain)", "Fatty Acid Metabolism (Acyl Carnitine, Monounsaturated)", "Fatty Acid Metabolism (Acyl Carnitine, Polyunsaturated)", "Fatty Acid Metabolism (Acyl Carnitine, Short Chain)")
bile_subpaths <- c("Primary Bile Acid Metabolism", "Secondary Bile Acid Metabolism")
steroid_subpaths <- c("Pregnenolone Steroids", "Corticosteroids", "Progestin Steroids", "Androgenic Steroids")
purine_subpaths <- c("Xanthine Metabolism", "Purine Metabolism, (Hypo)Xanthine/Inosine containing", "Purine Metabolism, Adenine containing", "Purine Metabolism, Guanine containing")

base_keywords <- "(tryptophan|kynuren|quinolin|kynurenic|xanthuren|anthranil|ethanolamide|PEA\\b|AEA\\b|2-AG\\b|arachidonoyl)"

annotation$PTSDBioPriority_v8 <- (annotation$SUB_PATHWAY %in% c(mito_subpaths, lipid_subpaths, fa_subpaths, bile_subpaths, steroid_subpaths, purine_subpaths)) | grepl(base_keywords, annotation$CHEMICAL_NAME, ignore.case = TRUE)

priority_names <- c("serotonin", "5-hydroxyindoleacetate", "5-hydroxyindoleacetic acid", "5-HIAA", "tryptophan", "tryptamine", "melatonin", "dopamine", "dopac", "3,4-dihydroxyphenylacetate", "homovanillate", "homovanillic acid", "3-methoxytyramine", "norepinephrine", "noradrenaline", "epinephrine", "adrenaline", "metanephrine", "normetanephrine", "vanillylmandelate", "VMA", "glutamate", "glutamine", "GABA", "gamma-aminobutyrate", "acetylcholine", "choline", "histamine", "histidine")

nm <- tolower(annotation$CHEMICAL_NAME)
match_idx <- rep(FALSE, length(nm))
for (p in priority_names) {
  p_low <- tolower(p)
  hit <- (nm == p_low) | grepl(paste0("\\b", gsub(" ", "\\\\s+", p_low), "\\b"), nm)
  match_idx <- match_idx | hit
}
annotation$Neuro_addon_v12 <- match_idx
annotation$V12_panel <- annotation$PTSDBioPriority_v8 | annotation$Neuro_addon_v12

# Get valid target CHEM_IDs
v12_target_ids <- as.character(annotation$CHEM_ID[annotation$V12_panel])
# Absolute Exemption for calculated neuro/energy indices
v12_target_ids <- c(v12_target_ids, "GABR", "Glycolytic_Ratio")

rows_to_keep <- rownames(mat_final) %in% v12_target_ids

cat(paste("Total metabolites before V12 filter:", nrow(mat_final), "\n"))
cat(paste("V12 features detected in matrix:", sum(rows_to_keep), "\n"))
mat_final <- mat_final[rows_to_keep, ]
cat(paste("Final V12 Panel metabolite count inside Matrix:", nrow(mat_final), "\n"))

# --- 4. Analysis Functions ---

run_limma_analysis <- function(target_mat, target_metadata, group_col, contrasts_list, prefix) {
  
  cat(paste("\nRunning analysis for:", prefix, "\n"))
  
  # Define Group
  Groups <- factor(target_metadata[[group_col]])
  # Clean group names to be valid R variable names
  levels(Groups) <- make.names(levels(Groups))
  
  # Design Matrix
  # Include covariates
  design <- model.matrix(~0 + Groups + Age + Gender + BMI, data = target_metadata)
  colnames(design)[1:nlevels(Groups)] <- levels(Groups)
  
  # Check for Cohort effect if applicable (if more than 1 cohort present)
  if (length(unique(target_metadata$Cohort)) > 1) {
    cat("Including Cohort in design matrix.\n")
    # Add Cohort to design, careful with reference level
    # Since we use 0 + Groups, we should add Cohort as factor but need to avoid singularity if Cohort is perfectly confounded
    # For safety, let's try adding it. If it fails, users can refine.
    # Usually: ~0 + Groups + Age + Gender + BMI + Cohort
    # Note: Cohort might need to be numeric or factor.
    design <- model.matrix(~0 + Groups + Age + Gender + BMI + Cohort, data = target_metadata)
    colnames(design)[1:nlevels(Groups)] <- levels(Groups) # Re-assign group names
  }
  
  # Fit Model
  fit <- lmFit(target_mat, design)
  
  # Contrasts
  # Map user friendly contrast names to make.names versions
  # contrasts_list is a named vector: Name = "Group1 - Group2"
  # We need to ensure Group1 and Group2 are in levels(Groups)
  
  valid_contrasts <- c()
  for (c_name in names(contrasts_list)) {
    contrast_expr <- contrasts_list[[c_name]]
    # Check if levels exist
    # Simple check: extract words
    vars <- unlist(str_extract_all(contrast_expr, "[A-Za-z0-9_.]+"))
    if (all(vars %in% colnames(design))) {
      valid_contrasts[c_name] <- contrast_expr
    } else {
      cat(paste("Warning: Skipping contrast", c_name, "- levels not found in design matrix.\n"))
      print(vars[!vars %in% colnames(design)])
    }
  }
  
  if (length(valid_contrasts) == 0) {
    cat("No valid contrasts found.\n")
    return(NULL)
  }
  
  contrast_matrix <- makeContrasts(contrasts = valid_contrasts, levels = design)
  colnames(contrast_matrix) <- names(valid_contrasts) # Explicitly name columns
  
  fit2 <- contrasts.fit(fit, contrast_matrix)
  fit2 <- eBayes(fit2)
  
  # Save Results
  for (c_name in names(valid_contrasts)) {
    # Debug info
    if (!c_name %in% colnames(fit2$coefficients)) {
        cat(paste("Error: Contrast", c_name, "not found in fit object coefficients.\n"))
        print(colnames(fit2$coefficients))
        next
    }
    
    res <- topTable(fit2, coef = c_name, number = Inf, sort.by = "P")
    
    # Annotate
    res$CHEM_ID <- rownames(res)
    # Merge with annotation (ensure CHEM_ID is character or numeric matching)
    # annotation$CHEM_ID is numeric based on inspection
    
    # Store original ID (which might be "GABR") before numeric conversion
    res$Original_ID <- res$CHEM_ID
    
    res$CHEM_ID <- as.numeric(res$CHEM_ID)
    
    res_annotated <- left_join(res, annotation, by = "CHEM_ID")
    
    # Restore Name for GABR/Glycolytic if merge failed (NA)
    res_annotated$CHEMICAL_NAME <- ifelse(is.na(res_annotated$CHEMICAL_NAME), res_annotated$Original_ID, res_annotated$CHEMICAL_NAME)
    
    filename <- file.path(output_dir, paste0(prefix, "_", c_name, ".csv"))
    write.csv(res_annotated, filename, row.names = FALSE)
    cat(paste("Saved:", filename, "\n"))
  }
}

# --- 5. Analysis 1: Cognitive Impairment ---
# Groups: "+ Cognitive Impairment", "- Cognitive Impairment", "Control"
# Variable: cognitive_function (has +/-, NA) & PTSD_status_binary (Control)

# Construct a composite group variable
meta_cog <- metadata_final %>%
  mutate(
    Group_Cog = case_when(
      PTSD_status_binary == "Control" ~ "Control",
      cognitive_function == "+ Cognitive Impairment" ~ "Cog_Pos",
      cognitive_function == "- Cognitive Impairment" ~ "Cog_Neg",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(Group_Cog))

# Data subset
mat_cog <- mat_final[, metadata_final$Metabolon_ID %in% meta_cog$Metabolon_ID]
# Ensure order matches
# Re-match because we filtered meta_cog
meta_cog <- meta_cog %>% arrange(Metabolon_ID)
mat_cog <- mat_cog[, meta_cog$Metabolon_ID]

# Define Contrasts
# 1. Cog_Pos - Cog_Neg
# 2. Cog_Pos - Control
contrasts_cog <- c(
  "CogPos_vs_CogNeg" = "Cog_Pos - Cog_Neg",
  "CogPos_vs_Control" = "Cog_Pos - Control"
)

run_limma_analysis(mat_cog, meta_cog, "Group_Cog", contrasts_cog, "Cognitive")


# --- 6. Analysis 2: Subtypes ---
# Groups: 4 subtypes vs Control
# Variable: four_subtypes & PTSD_status_binary

meta_sub <- metadata_final %>%
  mutate(
    Group_Sub = case_when(
      PTSD_status_binary == "Control" ~ "Control",
      four_subtypes == "Depressive Symptom Subtype" ~ "Depressive",
      four_subtypes == "Impaired Cognitive Function" ~ "Cognitive",
      four_subtypes == "Subthreshold/Mild PTSD Subtype" ~ "MildPTSD",
      four_subtypes == "Moderate/Severe PTSD Subtype" ~ "SeverePTSD",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(Group_Sub))

mat_sub <- mat_final[, metadata_final$Metabolon_ID %in% meta_sub$Metabolon_ID]
meta_sub <- meta_sub %>% arrange(Metabolon_ID)
mat_sub <- mat_sub[, meta_sub$Metabolon_ID]

contrasts_sub <- c(
  "Depressive_vs_Control" = "Depressive - Control",
  "Cognitive_vs_Control" = "Cognitive - Control",
  "MildPTSD_vs_Control" = "MildPTSD - Control",
  "SeverePTSD_vs_Control" = "SeverePTSD - Control"
)

run_limma_analysis(mat_sub, meta_sub, "Group_Sub", contrasts_sub, "Subtypes")

cat("\nAnalysis complete. Results saved in:", output_dir, "\n")

