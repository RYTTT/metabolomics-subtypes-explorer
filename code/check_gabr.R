out_dir <- "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/result_FINAL_PRODUCTION/IPW_V12_Six_Comparisons"
files <- list.files(out_dir, pattern=".csv$", full.names=TRUE)
for(f in files) {
  res <- read.csv(f)
  cat(basename(f), "\n")
  gabr <- res[res$Original_ID == "GABR", c("Original_ID", "logFC", "P.Value", "adj.P.Val")]
  print(gabr)
}
