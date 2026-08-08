import os
import re

workshop_script = "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/workshop/code/run_metabolomics_analysis_V12_workshop.R"

with open(workshop_script, 'r') as f:
    content = f.read()

# We need to remove from "1b. Age Correction" down to right before "2. Data Preparation"
pattern = re.compile(r'# --- 1b\. Age Correction.*?# --- 2\. Data Preparation ---', re.DOTALL)
new_content = pattern.sub('# --- 2. Data Preparation ---\n', content)

with open(workshop_script, 'w') as f:
    f.write(new_content)

print("Successfully stripped demographic correction logic.")
