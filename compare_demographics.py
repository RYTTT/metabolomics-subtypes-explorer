import pandas as pd
import numpy as np

base_dir = "/Users/ruotingyang/Desktop/Projects/Meta subtype"
excel_path = f"{base_dir}/Meta subtype  Antigravity/resource/Bridged metabolomics data_subtype analysis_2026.4.22_NEW CONTROLS-2.xlsx"
epi_path = f"{base_dir}/EpiagePTSD.csv"
ptsd_path = f"{base_dir}/allPTSDsamples 20170303.txt"

# 1. Load Excel Demographics
df_demo = pd.read_excel(excel_path, sheet_name="demographics")
df_demo['ID_str'] = df_demo['ID'].astype(str)

print(f"Total samples in demographics: {len(df_demo)}")

# 2. Check EpiagePTSD
try:
    df_epi = pd.read_csv(epi_path)
    # The R script extracted numeric ID from rownames. In pandas, it's the first column.
    df_epi['Extracted_ID'] = df_epi.iloc[:, 0].astype(str).str.extract(r'^(\d+)')[0]
    epi_ages = df_epi.groupby('Extracted_ID')['Age'].mean().reset_index()
    epi_ages.rename(columns={'Age': 'Epi_Age'}, inplace=True)
    
    # Merge and compare
    merged_age = pd.merge(df_demo, epi_ages, left_on='ID_str', right_on='Extracted_ID', how='inner')
    
    diff_age = merged_age[merged_age['Age'] != merged_age['Epi_Age']]
    diff_age_not_na = merged_age[(merged_age['Age'].notna()) & (merged_age['Epi_Age'].notna()) & (merged_age['Age'] != merged_age['Epi_Age'])]
    
    print(f"\n--- EpiagePTSD.csv Comparison ---")
    print(f"Samples matched: {len(merged_age)}")
    print(f"Number of samples where Epi_Age differs from source Age: {len(diff_age)}")
    if len(diff_age) > 0:
        print("Examples of differences (ID, Source Age, Epi Age):")
        print(diff_age[['ID', 'Age', 'Epi_Age']].head(10))
except Exception as e:
    print(f"Error reading EpiagePTSD: {e}")

# 3. Check allPTSDsamples
try:
    df_ptsd = pd.read_csv(ptsd_path, sep='\t')
    df_ptsd['Extracted_ID'] = df_ptsd['Name'].astype(str).str.extract(r'^(\d+)')[0]
    ptsd_bmi = df_ptsd.groupby('Extracted_ID')['BMI'].mean().reset_index()
    ptsd_bmi.rename(columns={'BMI': 'PTSD_BMI'}, inplace=True)
    
    # Merge and compare
    merged_bmi = pd.merge(df_demo, ptsd_bmi, left_on='ID_str', right_on='Extracted_ID', how='inner')
    
    # The R script updates BMI for SBC cohort or if it's missing
    sbc_mask = merged_bmi['Cohort'] == 'SBC'
    
    # Differences where source BMI is NOT missing, but PTSD_BMI is different
    diff_bmi = merged_bmi[(merged_bmi['BMI'].notna()) & (merged_bmi['PTSD_BMI'].notna()) & (np.abs(merged_bmi['BMI'] - merged_bmi['PTSD_BMI']) > 0.01)]
    
    print(f"\n--- allPTSDsamples 20170303.txt Comparison ---")
    print(f"Samples matched: {len(merged_bmi)}")
    print(f"Number of samples where PTSD_BMI differs from source BMI (when both exist): {len(diff_bmi)}")
    
    # How many missing BMIs does it fill?
    missing_source = merged_bmi[merged_bmi['BMI'].isna() & merged_bmi['PTSD_BMI'].notna()]
    print(f"Number of missing BMIs it successfully fills: {len(missing_source)}")
    
    if len(diff_bmi) > 0:
        print("Examples of existing BMI differences (ID, Source BMI, PTSD BMI):")
        print(diff_bmi[['ID', 'BMI', 'PTSD_BMI']].head(10))
except Exception as e:
    print(f"Error reading allPTSDsamples: {e}")
