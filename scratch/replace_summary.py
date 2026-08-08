import re

file_path = "workshop/code/run_metabolomics_analysis_V12_workshop.R"

with open(file_path, "r") as f:
    content = f.read()

# Define the new HTML generation logic
html_logic = """
# Format as a nice HTML Clinical Demographics Table
html_file <- file.path(working_dir, "Meta subtype  Antigravity", "workshop", "report", "Clinical_Demographics_Table.html")
sink(html_file)
cat("<html><head><style>")
cat("table { border-collapse: collapse; width: 100%; font-family: sans-serif; }")
cat("th, td { border: 1px solid #ddd; padding: 8px; text-align: center; }")
cat("th { background-color: #f2f2f2; }")
cat("</style></head><body>")
cat("<h2>Clinical Demographics Table</h2>")
cat("<table>")
cat("<tr><th>Variable</th>")
for (g in summary_stats$Group_Sub) cat(paste0("<th>", g, " (n=", summary_stats$N[summary_stats$Group_Sub==g], ")</th>"))
cat("</tr>")

# Age
cat("<tr><td><b>Age (mean ± SD)</b></td>")
for (g in summary_stats$Group_Sub) cat(paste0("<td>", round(summary_stats$Age_Mean[summary_stats$Group_Sub==g], 2), " ± ", round(summary_stats$Age_SD[summary_stats$Group_Sub==g], 2), "</td>"))
cat("</tr>")

# BMI
cat("<tr><td><b>BMI (mean ± SD)</b></td>")
for (g in summary_stats$Group_Sub) cat(paste0("<td>", round(summary_stats$BMI_Mean[summary_stats$Group_Sub==g], 2), " ± ", round(summary_stats$BMI_SD[summary_stats$Group_Sub==g], 2), "</td>"))
cat("</tr>")

# Gender M
cat("<tr><td><b>Male n (%)</b></td>")
for (g in summary_stats$Group_Sub) {
  n <- summary_stats$Male[summary_stats$Group_Sub==g]
  tot <- summary_stats$N[summary_stats$Group_Sub==g]
  pct <- round(n/tot*100, 1)
  cat(paste0("<td>", n, " (", pct, "%)</td>"))
}
cat("</tr>")

# Gender F
cat("<tr><td><b>Female n (%)</b></td>")
for (g in summary_stats$Group_Sub) {
  n <- summary_stats$Female[summary_stats$Group_Sub==g]
  tot <- summary_stats$N[summary_stats$Group_Sub==g]
  pct <- round(n/tot*100, 1)
  cat(paste0("<td>", n, " (", pct, "%)</td>"))
}
cat("</tr>")

cat("</table></body></html>")
sink()
cat("Summary HTML saved to workshop/report/Clinical_Demographics_Table.html\n")
"""

# Replace the CSV writing logic
content = re.sub(
    r'write\.csv\(summary_stats.*?cat\("Summary statistics saved.*?\\n"\)',
    html_logic,
    content,
    flags=re.DOTALL
)

with open(file_path, "w") as f:
    f.write(content)
