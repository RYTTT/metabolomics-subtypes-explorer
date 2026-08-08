import re

file_path = "workshop/code/run_metabolomics_analysis_V12_workshop.R"

with open(file_path, "r") as f:
    content = f.read()

# Fix the mutate pipeline
old_mutate = """summary_stats <- metadata_final %>%
  mutate(Group_Sub = case_when(
    PTSD_status_binary == "Control" ~ "Control",
    four_subtypes == "Depressive Symptom Subtype" ~ "Depressive",
    four_subtypes == "Impaired Cognitive Function" ~ "Cognitive",
    four_subtypes == "Subthreshold/Mild PTSD Subtype" ~ "MildPTSD",
    four_subtypes == "Moderate/Severe PTSD Subtype" ~ "SeverePTSD",
  )) %>%
  filter(!is.na(Group_Sub)) %>%
  group_by(Group_Sub) %>%
  summarize("""

new_mutate = """metadata_for_stats <- metadata_final %>%
  mutate(Group_Sub = case_when(
    PTSD_status_binary == "Control" ~ "Control",
    four_subtypes == "Depressive Symptom Subtype" ~ "Depressive",
    four_subtypes == "Impaired Cognitive Function" ~ "Cognitive",
    four_subtypes == "Subthreshold/Mild PTSD Subtype" ~ "MildPTSD",
    four_subtypes == "Moderate/Severe PTSD Subtype" ~ "SeverePTSD",
  )) %>%
  filter(!is.na(Group_Sub))

summary_stats <- metadata_for_stats %>%
  group_by(Group_Sub) %>%
  summarize("""

content = content.replace(old_mutate, new_mutate)

# Replace metadata_final with metadata_for_stats in the p-value calculations
content = content.replace("data=metadata_final", "data=metadata_for_stats")
content = content.replace("metadata_final$Gender, metadata_final$Group_Sub", "metadata_for_stats$Gender, metadata_for_stats$Group_Sub")

with open(file_path, "w") as f:
    f.write(content)
