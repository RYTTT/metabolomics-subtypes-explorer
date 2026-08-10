#!/usr/bin/env python3
"""
Metabolomics Data Pipeline v2.0
- Loads differential expression CSVs
- Annotates with comprehensive metabolite_annotations.json
- Filters out invalid entries (nan IDs)
- Outputs src-ready JSON
"""
import pandas as pd
import json
import os

BASE_DIR = "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity"
v12_dir = os.path.join(BASE_DIR, "result_V12")
final_prod_dir = os.path.join(BASE_DIR, "result_FINAL_PRODUCTION/IPW_Six_Comparisons")

file_mapping = {
    "Depressive_vs_Control": os.path.join(v12_dir, "Subtypes_Depressive_vs_Control.csv"),
    "Cognitive_vs_Control": os.path.join(v12_dir, "Subtypes_Cognitive_vs_Control.csv"),
    "MildPTSD_vs_Control": os.path.join(v12_dir, "Subtypes_MildPTSD_vs_Control.csv"),
    "SeverePTSD_vs_Control": os.path.join(v12_dir, "Subtypes_SeverePTSD_vs_Control.csv"),
    "MildPTSD_vs_SeverePTSD": os.path.join(BASE_DIR, "result_FINAL_PRODUCTION/IPW_V12_Six_Comparisons/Pairwise_MildPTSD_vs_SeverePTSD.csv"),
    "CogPos_vs_CogNeg": os.path.join(v12_dir, "Cognitive_CogPos_vs_CogNeg.csv")
}

# ── Load the comprehensive annotation database ──
anno_path = os.path.join(BASE_DIR, "data/metabolite_annotations.json")
with open(anno_path) as f:
    anno_db = json.load(f)
ANNOTATIONS = anno_db["annotations"]

def find_annotation(chem_name, sub_pathway, super_pathway):
    """
    Match metabolite to annotation using controlled pattern matching.
    match_field controls which text is searched to prevent false positives:
      - name_only: pattern must match in chemical name only
      - subpathway_only: pattern must match in sub_pathway only
      - superpathway_only: pattern must match in super_pathway only
      - name_or_subpathway: pattern can match in name OR sub_pathway (default)
    """
    name_lower = chem_name.lower()
    subpath_lower = sub_pathway.lower() if sub_pathway else ""
    superpath_lower = super_pathway.lower() if super_pathway else ""

    for anno in ANNOTATIONS:
        match_field = anno.get("match_field", "name_or_subpathway")

        for pat in anno["pattern"]:
            pat_lower = pat.lower()
            matched = False

            if match_field == "name_only":
                matched = pat_lower in name_lower
            elif match_field == "subpathway_only":
                matched = pat_lower in subpath_lower
            elif match_field == "superpathway_only":
                matched = pat_lower in superpath_lower
            elif match_field == "name_or_subpathway":
                matched = pat_lower in name_lower or pat_lower in subpath_lower

            if matched:
                return anno

    # Fallback
    return {
        "disorders": ["General Metabolomics"],
        "mechanism": f"Differentially expressed metabolite in {super_pathway or 'metabolomics panel'} ({sub_pathway or 'general pathway'}). Biological mechanism annotation pending for this specific compound.",
        "pathway_category": super_pathway or "Metabolic Pathway",
        "references": []
    }


# ── Process CSV files ──
metabolite_dict = {}

for comp_key, filepath in file_mapping.items():
    if not os.path.exists(filepath):
        print(f"WARNING: {filepath} not found!")
        continue

    df = pd.read_csv(filepath)
    print(f"Processing {comp_key} ({len(df)} rows)")

    for _, row in df.iterrows():
        raw_name = row.get("CHEMICAL_NAME")
        raw_cid = row.get("CHEM_ID")

        # Resolve chemical name
        if pd.notna(raw_name) and str(raw_name).strip() not in ("", "nan"):
            chem_name = str(raw_name).strip()
        elif pd.notna(raw_cid) and str(raw_cid).strip() not in ("", "nan"):
            chem_name = str(raw_cid).strip()
        else:
            continue  # Skip completely invalid rows

        # Resolve chem_id
        if pd.notna(raw_cid) and str(raw_cid).strip() not in ("", "nan"):
            chem_id = str(raw_cid).replace(".0", "").strip()
        else:
            chem_id = chem_name  # Use name as ID for composite indices (GABR, Glycolytic_Ratio)

        # Skip if both name and ID resolve to 'nan'
        if chem_id == "nan" or chem_name == "nan":
            continue

        # Create new metabolite entry
        if chem_id not in metabolite_dict:
            super_p = str(row.get("SUPER_PATHWAY", "")) if pd.notna(row.get("SUPER_PATHWAY")) and str(row.get("SUPER_PATHWAY")) != "nan" else ("Composite Index" if chem_id in ["GABR", "Glycolytic_Ratio"] else "Uncategorized")
            sub_p = str(row.get("SUB_PATHWAY", "")) if pd.notna(row.get("SUB_PATHWAY")) and str(row.get("SUB_PATHWAY")) != "nan" else ("Composite Index" if chem_id in ["GABR", "Glycolytic_Ratio"] else "Uncategorized")

            anno = find_annotation(chem_name, sub_p, super_p)
            metabolite_dict[chem_id] = {
                "chem_id": chem_id,
                "chemical_name": chem_name,
                "plot_name": str(row.get("PLOT_NAME", chem_name)) if pd.notna(row.get("PLOT_NAME")) else chem_name,
                "super_pathway": super_p,
                "sub_pathway": sub_p,
                "hmdb": str(row.get("HMDB", "")) if pd.notna(row.get("HMDB")) and str(row.get("HMDB")) not in ("NA", "nan") else "",
                "kegg": str(row.get("KEGG", "")) if pd.notna(row.get("KEGG")) and str(row.get("KEGG")) not in ("NA", "nan") else "",
                "pubchem": str(row.get("PUBCHEM", "")) if pd.notna(row.get("PUBCHEM")) and str(row.get("PUBCHEM")) not in ("NA", "nan") else "",
                "cas": str(row.get("CAS", "")) if pd.notna(row.get("CAS")) and str(row.get("CAS")) not in ("NA", "nan") else "",
                "chemspider": str(row.get("CHEMSPIDER", "")) if pd.notna(row.get("CHEMSPIDER")) and str(row.get("CHEMSPIDER")) not in ("NA", "nan") else "",
                "inchikey": str(row.get("INCHIKEY", "")) if pd.notna(row.get("INCHIKEY")) and str(row.get("INCHIKEY")) not in ("NA", "nan") else "",
                "smiles": str(row.get("SMILES", "")) if pd.notna(row.get("SMILES")) and str(row.get("SMILES")) not in ("NA", "nan") else "",
                "v12_panel": bool(row.get("V12_panel", True if chem_id in ["GABR", "Glycolytic_Ratio"] else False)),
                "ptsd_biopriority": bool(row.get("PTSDBioPriority_v8", True if chem_id in ["GABR", "Glycolytic_Ratio"] else False)),
                "neuro_addon": bool(row.get("Neuro_addon_v12", False)),
                "disorders": anno["disorders"],
                "mechanism": anno["mechanism"],
                "pathway_category": anno["pathway_category"],
                "references": anno.get("references", []),
                "comparisons": {}
            }

        # Add comparison stats
        log_fc = float(row["logFC"]) if pd.notna(row.get("logFC")) else 0.0
        p_val = float(row["P.Value"]) if pd.notna(row.get("P.Value")) else 1.0
        adj_p = float(row["adj.P.Val"]) if pd.notna(row.get("adj.P.Val")) else 1.0
        t_stat = float(row["t"]) if pd.notna(row.get("t")) else 0.0
        ave_expr = float(row["AveExpr"]) if pd.notna(row.get("AveExpr")) else 0.0
        b_stat = float(row["B"]) if pd.notna(row.get("B")) else 0.0

        if p_val < 0.05:
            color = "red" if log_fc > 0 else "blue"
            direction = "UP" if log_fc > 0 else "DOWN"
        else:
            color = "grey"
            direction = "NC"

        p_tier = "NS"
        if adj_p < 0.1:
            p_tier = "FDR < 0.1"
        elif p_val < 0.01:
            p_tier = "P < 0.01"
        elif p_val < 0.05:
            p_tier = "P < 0.05"

        metabolite_dict[chem_id]["comparisons"][comp_key] = {
            "logFC": log_fc,
            "P.Value": p_val,
            "adj.P.Val": adj_p,
            "t": t_stat,
            "AveExpr": ave_expr,
            "B": b_stat,
            "color": color,
            "direction": direction,
            "p_tier": p_tier
        }

metabolites_list = list(metabolite_dict.values())

# ── QC Report ──
total = len(metabolites_list)
annotated = sum(1 for m in metabolites_list if "General Metabolomics" not in m["disorders"])
generic = total - annotated

sig_01 = set()
fdr_01 = set()
for m in metabolites_list:
    for c in m["comparisons"].values():
        if c["P.Value"] < 0.01:
            sig_01.add(m["chem_id"])
        if c["adj.P.Val"] < 0.1:
            fdr_01.add(m["chem_id"])

print(f"\n{'='*60}")
print(f"QC REPORT")
print(f"{'='*60}")
print(f"Total metabolites:       {total}")
print(f"Annotated (specific):    {annotated} ({annotated/total*100:.1f}%)")
print(f"Generic fallback:        {generic} ({generic/total*100:.1f}%)")
print(f"Significant P<0.01:      {len(sig_01)}")
print(f"FDR<0.1 discoveries:     {len(fdr_01)}")

# Check for nan entries
nan_entries = [m for m in metabolites_list if m["chem_id"] == "nan" or m["chemical_name"] == "nan"]
if nan_entries:
    print(f"\nWARNING: {len(nan_entries)} entries with nan chem_id or name!")
else:
    print(f"\n✓ No nan entries detected")

# Check for false-positive bile annotations on glycolysis metabolites
false_pos = [m for m in metabolites_list if "Bile Acid" in m["pathway_category"] and "bile" not in m["sub_pathway"].lower() and "bile" not in m["chemical_name"].lower() and "cholate" not in m["chemical_name"].lower() and "cholenate" not in m["chemical_name"].lower()]
if false_pos:
    print(f"\nWARNING: {len(false_pos)} false-positive bile annotations:")
    for fp in false_pos:
        print(f"  {fp['chemical_name']} [{fp['sub_pathway']}]")
else:
    print(f"✓ No false-positive bile annotations")

print(f"{'='*60}\n")

# ── Write outputs ──
output_path = os.path.join(BASE_DIR, "data/metabolites_data.json")
with open(output_path, "w") as f:
    json.dump(metabolites_list, f, indent=2)

src_output = os.path.join(BASE_DIR, "src/data/metabolites_data.json")
with open(src_output, "w") as f:
    json.dump(metabolites_list, f, indent=2)

print(f"Saved {total} metabolites to {output_path}")
print(f"Copied to {src_output}")
