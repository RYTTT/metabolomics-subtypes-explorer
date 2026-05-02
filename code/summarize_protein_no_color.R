library(dplyr)
library(readxl)

file_path <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/resource/Protein subtype analysis_summary 4.28.2026.xlsx"
out_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/result_FINAL_PRODUCTION"
doc_file <- file.path(out_dir, "Protein_DE_summary.doc")

sheets <- excel_sheets(file_path)

sink(doc_file)

cat("<html><head><meta charset='utf-8'></head><body>\n")
cat("<h2>Differential Protein Expression Summary</h2>\n")
cat("<p>Grouped by Protein Category. Showing significant proteins (P < 0.05). Note: Direction of regulation (logFC) is currently unavailable.</p>\n")

cat("<table border='1' style='border-collapse: collapse; width: 100%;'>\n")
cat("<tr>\n")
cat("<th>Comparison</th><th>P < 0.05</th><th>P < 0.01</th><th>P < 0.05 Proteins (Grouped)</th>\n")
cat("</tr>\n")

for (s in sheets) {
  df <- read_excel(file_path, sheet = s)
  if(nrow(df) == 0) next
  
  # Clean p-value
  df$numeric_p <- suppressWarnings(as.numeric(gsub("<", "", df[["p-value"]])))
  
  # Count totals
  p05 <- sum(df$numeric_p < 0.05, na.rm=TRUE)
  p01 <- sum(df$numeric_p < 0.01, na.rm=TRUE)
  
  # Filter significant
  df_sig <- df %>% filter(numeric_p < 0.05) %>% arrange(numeric_p)
  
  if(nrow(df_sig) == 0) {
    metabs_str <- ""
  } else {
    # Format each protein name
    df_sig$formatted <- sapply(1:nrow(df_sig), function(i) {
      stars <- ""
      if(!is.na(df_sig$numeric_p[i]) && df_sig$numeric_p[i] < 0.01) stars <- "**"
      else if (!is.na(df_sig$numeric_p[i]) && df_sig$numeric_p[i] < 0.05) stars <- "*"
      
      sprintf("%s%s", df_sig[["Protein Name"]][i], stars)
    })
    
    # Handle missing categories
    df_sig[["Protein Category"]] <- ifelse(is.na(df_sig[["Protein Category"]]), "Other/Unspecified", df_sig[["Protein Category"]])
    
    # Group by Protein Category
    df_sig <- df_sig %>% arrange(`Protein Category`)
    category_groups <- split(df_sig$formatted, df_sig[["Protein Category"]])
    
    # Build final string
    out_str <- c()
    for(cat_name in sort(names(category_groups))) {
      items <- paste(category_groups[[cat_name]], collapse=", ")
      out_str <- c(out_str, sprintf("<b><u>%s</u></b>: %s", cat_name, items))
    }
    metabs_str <- paste(out_str, collapse="<br/><br/>")
  }
  
  cat("<tr>\n")
  cat(sprintf("<td>%s</td><td>%d</td><td>%d</td><td>%s</td>\n", 
              s, p05, p01, metabs_str))
  cat("</tr>\n")
}

cat("</table>\n")
cat("</body></html>\n")

sink()
cat("Protein summary generated at:", doc_file, "\n")
