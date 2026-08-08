import re

file_path = "workshop/code/run_metabolomics_analysis_V12_workshop.R"

with open(file_path, "r") as f:
    content = f.read()

# We need to insert the p-value calculations right after summary_stats is defined
# and before the HTML generation.
calc_code = """
  )

# Calculate P-values across groups
p_age <- tryCatch(anova(lm(Age ~ Group_Sub, data=metadata_final))[1, "Pr(>F)"], error=function(e) NA)
p_bmi <- tryCatch(anova(lm(BMI ~ Group_Sub, data=metadata_final))[1, "Pr(>F)"], error=function(e) NA)
tbl_gender <- table(metadata_final$Gender, metadata_final$Group_Sub)
p_gender <- tryCatch(chisq.test(tbl_gender)$p.value, error=function(e) NA)

format_p <- function(p) {
  if (is.na(p)) return("NA")
  if (p < 0.001) return("<0.001")
  return(sprintf("%.3f", p))
}
"""

content = re.sub(r'  \)\n\n\n# Format as a nice HTML', calc_code + "\n\n# Format as a nice HTML", content)

# Now add the <th>P-value</th> to the header
content = content.replace(
    'cat("</tr>")\n\n# Age',
    'cat("<th>P-value</th></tr>")\n\n# Age'
)

# Add p-values to rows
content = content.replace(
    'cat("</tr>")\n\n# BMI',
    'cat(paste0("<td>", format_p(p_age), "</td></tr>"))\n\n# BMI'
)

content = content.replace(
    'cat("</tr>")\n\n# Gender M',
    'cat(paste0("<td>", format_p(p_bmi), "</td></tr>"))\n\n# Gender M'
)

content = content.replace(
    'cat("</tr>")\n\n# Gender F',
    'cat(paste0("<td rowspan=\'2\'>", format_p(p_gender), "</td></tr>"))\n\n# Gender F'
)

# Wait, for Gender F row, we don't need a cell if rowspan=2 on Male, but let's just leave it empty or remove rowspan
content = content.replace(
    "<td rowspan='2'>", "<td>"
)
content = content.replace(
    'cat("</tr>")\n\ncat("</table></body></html>")',
    'cat("<td></td></tr>")\n\ncat("</table></body></html>")'
)

with open(file_path, "w") as f:
    f.write(content)

