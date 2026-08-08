import os
import re

base_dir = "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity"
workshop_dir = os.path.join(base_dir, "workshop")

# --- Demo 2 & 1: Modifying run_metabolomics_analysis_V12.R ---
with open(os.path.join(base_dir, "code", "run_metabolomics_analysis_V12.R"), "r") as f:
    v12_code = f.read()

# Change paths
v12_code = v12_code.replace(
    'input_path <- file.path(working_dir, "Meta subtype  Antigravity", "resource", file_name)',
    'input_path <- file.path(working_dir, "Meta subtype  Antigravity", "workshop", "source", file_name)'
)
v12_code = v12_code.replace(
    'output_dir <- file.path(working_dir, "Meta subtype  Antigravity", "result_V12")',
    'output_dir <- file.path(working_dir, "Meta subtype  Antigravity", "workshop", "result")'
)

# Inject Demo 1 Summary Statistics extraction logic right after mat_final is ready
demo1_logic = """
# --- Demo 1: Export Summary Statistics ---
cat("\nGenerating Summary Statistics for Demo 1...\n")
summary_stats <- metadata_final %>%
  mutate(Group_Sub = case_when(
    PTSD_status_binary == "Control" ~ "Control",
    four_subtypes == "Depressive Symptom Subtype" ~ "Depressive",
    four_subtypes == "Impaired Cognitive Function" ~ "Cognitive",
    four_subtypes == "Subthreshold/Mild PTSD Subtype" ~ "MildPTSD",
    four_subtypes == "Moderate/Severe PTSD Subtype" ~ "SeverePTSD",
    TRUE ~ NA_character_
  )) %>%
  filter(!is.na(Group_Sub)) %>%
  group_by(Group_Sub) %>%
  summarize(
    N = n(),
    Age_Mean = mean(Age, na.rm=TRUE),
    Age_SD = sd(Age, na.rm=TRUE),
    BMI_Mean = mean(BMI, na.rm=TRUE),
    BMI_SD = sd(BMI, na.rm=TRUE),
    Male = sum(Gender == "M", na.rm=TRUE),
    Female = sum(Gender == "F", na.rm=TRUE)
  )

write.csv(summary_stats, file.path(working_dir, "Meta subtype  Antigravity", "workshop", "report", "summary_stats.csv"), row.names=FALSE)
cat("Summary statistics saved to workshop/report/summary_stats.csv\n")
"""

v12_code = v12_code.replace("# --- 4. Analysis Functions ---", demo1_logic + "\n# --- 4. Analysis Functions ---")

# Inject Volcano Plot logic at the end of run_limma_analysis loop
volcano_logic = """
    # Volcano Plot
    library(ggplot2)
    png(file.path(output_dir, paste0(prefix, "_", c_name, "_volcano.png")), width=800, height=600)
    p <- ggplot(res_annotated, aes(x=logFC, y=-log10(P.Value), color=adj.P.Val < 0.1)) +
      geom_point(alpha=0.6) +
      scale_color_manual(values=c("grey", "red")) +
      theme_minimal() +
      labs(title=paste("Volcano Plot:", prefix, "-", c_name), x="Log2 Fold Change", y="-Log10 P-Value") +
      theme(legend.position="none")
    print(p)
    dev.off()
"""
v12_code = v12_code.replace('cat(paste("Saved:", filename, "\\n"))', 'cat(paste("Saved:", filename, "\\n"))\n' + volcano_logic)

with open(os.path.join(workshop_dir, "code", "run_metabolomics_analysis_V12_workshop.R"), "w") as f:
    f.write(v12_code)


# --- Demo 3: Modifying summarize_v12_grouped.R ---
with open(os.path.join(base_dir, "code", "summarize_v12_grouped.R"), "r") as f:
    sum_code = f.read()

sum_code = sum_code.replace(
    'out_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/result_V12"',
    'out_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/workshop/result"'
)
sum_code = sum_code.replace(
    'doc_file <- file.path(dirname(out_dir), "result_FINAL_PRODUCTION", "V12_DE_summary_Original_Grouped.doc")',
    'doc_file <- file.path(dirname(out_dir), "workshop", "report", "V12_DE_summary_Original_Grouped.doc")'
)

with open(os.path.join(workshop_dir, "code", "generate_word_report.R"), "w") as f:
    f.write(sum_code)

print("Python modification script ran successfully.")
