import pandas as pd
excel_path = "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/workshop/source/Bridged metabolomics data_subtype analysis_2026.4.22_NEW CONTROLS-2.xlsx"
xls = pd.ExcelFile(excel_path)
print("Sheets in the file:", xls.sheet_names)
