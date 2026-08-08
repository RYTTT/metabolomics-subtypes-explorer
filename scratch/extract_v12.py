import pandas as pd

# Load one of the result files which already has the V12 filtered metabolites
res_file = "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/workshop/result/Cognitive_CogPos_vs_Control.csv"
df = pd.read_csv(res_file)

# Extract relevant annotation columns for the V12 panel
v12_panel = df[['CHEM_ID', 'Original_ID', 'CHEMICAL_NAME', 'SUPER_PATHWAY', 'SUB_PATHWAY']].drop_duplicates()

# Save to workshop/source
out_file = "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/workshop/source/V12_panel_features.csv"
v12_panel.to_csv(out_file, index=False)
print(f"Saved {len(v12_panel)} V12 features to {out_file}")
