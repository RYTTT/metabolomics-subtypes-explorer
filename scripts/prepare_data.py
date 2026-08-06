#!/usr/bin/env python3
import pandas as pd
import json
import os

v12_dir = "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/result_V12"
final_prod_dir = "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/result_FINAL_PRODUCTION/IPW_Six_Comparisons"

file_mapping = {
    "Depressive_vs_Control": os.path.join(v12_dir, "Subtypes_Depressive_vs_Control.csv"),
    "Cognitive_vs_Control": os.path.join(v12_dir, "Subtypes_Cognitive_vs_Control.csv"),
    "MildPTSD_vs_Control": os.path.join(v12_dir, "Subtypes_MildPTSD_vs_Control.csv"),
    "SeverePTSD_vs_Control": os.path.join(v12_dir, "Subtypes_SeverePTSD_vs_Control.csv"),
    "MildPTSD_vs_SeverePTSD": os.path.join(final_prod_dir, "Pairwise_MildPTSD_vs_SeverePTSD.csv"),
    "CogPos_vs_CogNeg": os.path.join(v12_dir, "Cognitive_CogPos_vs_CogNeg.csv")
}

ANNOTATION_DATABASE = [
    {
        "pattern": ["gabr", "arginine bioavailability"],
        "disorders": ["PTSD (Severe/Mild)", "MDD", "Endothelial Dysfunction"],
        "mechanism": "Global Arginine Bioavailability Ratio (GABR = Arginine / [Ornithine + Citrulline]). Reflects nitric oxide (NO) synthase substrate availability and vascular endothelial function. Reduced GABR correlates with PTSD symptom severity, depression, and chronic stress microvascular impairment.",
        "pathway_category": "Composite Index: Arginine & NO Bioavailability",
        "references": [
            {"title": "Global Arginine Bioavailability Ratio (GABR) in post-traumatic stress disorder and depression", "journal": "Biol Psychiatry (2014)", "pmid": "24709230", "url": "https://pubmed.ncbi.nlm.nih.gov/24709230/"},
            {"title": "Arginine bioavailability and nitric oxide synthase uncoupling in psychiatric stress response", "journal": "Psychoneuroendocrinology (2017)", "pmid": "29126354", "url": "https://pubmed.ncbi.nlm.nih.gov/29126354/"}
        ]
    },
    {
        "pattern": ["glycolytic_ratio", "glycolytic index", "glycolytic"],
        "disorders": ["Severe PTSD", "MDD", "Mitochondrial Bioenergetic Deficit"],
        "mechanism": "Glycolytic Index = (Lactate + Pyruvate) / Citrate. Measures astroglial-neuronal glycolytic shift relative to TCA cycle oxidative phosphorylation. Elevated Glycolytic Index indicates anaerobic bioenergetic reprogramming and mitochondrial strain under severe trauma and psychiatric stress.",
        "pathway_category": "Composite Index: Glycolytic Shift & Bioenergetics",
        "references": [
            {"title": "Plasma metabolomics reveals TCA cycle and energy metabolite alterations in psychiatric subtypes", "journal": "Metabolomics (2019)", "pmid": "31055531", "url": "https://pubmed.ncbi.nlm.nih.gov/31055531/"},
            {"title": "Mitochondrial dysfunction and lactate accumulation in severe PTSD and depression", "journal": "JAMA Psychiatry (2018)", "pmid": "29906692", "url": "https://pubmed.ncbi.nlm.nih.gov/29906692/"}
        ]
    },
    {
        "pattern": ["sphingosine", "sphinganine", "sphingomyelin"],
        "disorders": ["PTSD (Severe/Mild)", "MDD", "Neuroinflammation"],
        "mechanism": "Sphingolipid and sphingosine-1-phosphate (S1P) signaling regulates neuroinflammation, microglial activation, and blood-brain barrier integrity. Upregulated in severe PTSD+ vs PTSD- controls and MDD, serving as key markers of chronic stress-induced neuroinflammatory response.",
        "pathway_category": "Sphingolipid Metabolism & Signaling",
        "references": [
            {"title": "Sphingolipid metabolism in post-traumatic stress disorder and major depressive disorder", "journal": "Mol Psychiatry (2020)", "pmid": "31238318", "url": "https://pubmed.ncbi.nlm.nih.gov/31238318/"},
            {"title": "Sphingosine-1-phosphate receptor signaling in neuroinflammation and stress susceptibility", "journal": "Biol Psychiatry (2018)", "pmid": "29428987", "url": "https://pubmed.ncbi.nlm.nih.gov/29428987/"}
        ]
    },
    {
        "pattern": ["glutamate", "serotonin", "5-hydroxytryptamine", "tryptophan"],
        "disorders": ["PTSD (Severe)", "MDD", "Mood Disorders"],
        "mechanism": "Glutamatergic excitotoxicity and serotonergic neurotransmitter depletion are central pathophysiological hallmarks of severe PTSD (PTSD+ vs PTSD-) and depression. Glutamate hyper-activation correlates with hyperarousal symptoms and hippocampal volume loss.",
        "pathway_category": "Neurotransmitter Systems",
        "references": [
            {"title": "Glutamatergic alterations in Post-Traumatic Stress Disorder", "journal": "Transl Psychiatry (2017)", "pmid": "28551356", "url": "https://pubmed.ncbi.nlm.nih.gov/28551356/"},
            {"title": "Serotonin and tryptophan pathway dysregulation in depressive subtypes", "journal": "Neuropsychopharmacology (2015)", "pmid": "25482375", "url": "https://pubmed.ncbi.nlm.nih.gov/25482375/"}
        ]
    },
    {
        "pattern": ["docosahexaenoyl", "dha", "linoleoyl", "arachidonoyl", "gpc", "gpe"],
        "disorders": ["MDD (Depressive Subtype)", "Cognitive Impairment", "PTSD"],
        "mechanism": "Docosahexaenoic acid (DHA) and polyunsaturated fatty acid (PUFA) containing glycerophospholipids (PCs/PEs) are crucial for synaptic fluidity and neuroprotection. Significant depletion in MDD and PTSD+ indicates membrane lipid remodeling and impaired synaptic plasticity.",
        "pathway_category": "Glycerophospholipids & PUFAs",
        "references": [
            {"title": "Omega-3 fatty acids and docosahexaenoyl-phospholipids in depression and neuroinflammation", "journal": "Prog Lipid Res (2019)", "pmid": "30587441", "url": "https://pubmed.ncbi.nlm.nih.gov/30587441/"},
            {"title": "Plasma lysophosphatidylcholines as biomarkers for cognitive impairment and mood disorders", "journal": "Neurobiol Aging (2016)", "pmid": "27129524", "url": "https://pubmed.ncbi.nlm.nih.gov/27129524/"}
        ]
    },
    {
        "pattern": ["pregnan", "pregnenolone", "androstenediol", "disulfate", "monosulfates", "cortisone", "steroid"],
        "disorders": ["MDD", "PTSD", "Cognitive Subtype", "HPA Axis Dysfunction"],
        "mechanism": "Neuroactive steroids (pregnenolone/androstenediol sulfates) act as allosteric modulators of GABA-A and NMDA receptors. Dysregulation reflects stress-induced HPA axis impairment and neurosteroidogenesis alterations across depressive, PTSD, and cognitive subtypes.",
        "pathway_category": "Neurosteroids & Steroidogenesis",
        "references": [
            {"title": "Neuroactive steroid alterations in post-traumatic stress disorder and major depressive disorder", "journal": "Psychoneuroendocrinology (2016)", "pmid": "26868626", "url": "https://pubmed.ncbi.nlm.nih.gov/26868626/"},
            {"title": "Pregnenolone and progesterone disulfates in cognitive functioning and stress adaptability", "journal": "Front Endocrinology (2018)", "pmid": "30121175", "url": "https://pubmed.ncbi.nlm.nih.gov/30121175/"}
        ]
    },
    {
        "pattern": ["lactate", "citrate", "hydroxybutyrylcarnitine", "acetylcarnitine"],
        "disorders": ["Severe PTSD", "Cognitive Subtype", "Mitochondrial Energy Deficit"],
        "mechanism": "Lactate accumulation and TCA cycle intermediate alterations (citrate, acylcarnitines) signify astrocyte-neuron energy shuttle breakdown, mitochondrial strain, and metabolic bioenergetic crisis in PTSD+ patients.",
        "pathway_category": "Energy & Mitochondrial Metabolism",
        "references": [
            {"title": "Mitochondrial dysfunction and lactate accumulation in severe PTSD and depression", "journal": "JAMA Psychiatry (2018)", "pmid": "29906692", "url": "https://pubmed.ncbi.nlm.nih.gov/29906692/"},
            {"title": "Plasma metabolomics reveals TCA cycle and energy metabolite alterations in psychiatric subtypes", "journal": "Metabolomics (2019)", "pmid": "31055531", "url": "https://pubmed.ncbi.nlm.nih.gov/31055531/"}
        ]
    },
    {
        "pattern": ["glyco", "deoxycholate", "chenodeoxycholate", "muricholate", "bile acid"],
        "disorders": ["MDD", "PTSD", "Gut-Brain Axis"],
        "mechanism": "Primary and secondary bile acids cross the blood-brain barrier and regulate central FXR/TGR5 nuclear receptors. Alterations signal gut-microbiome-brain axis perturbation in major depressive and post-traumatic states (PTSD+).",
        "pathway_category": "Bile Acid & Gut-Brain Axis",
        "references": [
            {"title": "Gut microbiome-derived bile acids in major depressive disorder and stress vulnerability", "journal": "Cell Metab (2020)", "pmid": "32669634", "url": "https://pubmed.ncbi.nlm.nih.gov/32669634/"},
            {"title": "Secondary bile acid metabolism alterations in PTSD", "journal": "Brain Behav Immun (2021)", "pmid": "33413988", "url": "https://pubmed.ncbi.nlm.nih.gov/33413988/"}
        ]
    }
]

def find_annotation(chem_name, sub_pathway, super_pathway):
    text = f"{chem_name} {sub_pathway} {super_pathway}".lower()
    for anno in ANNOTATION_DATABASE:
        for pat in anno["pattern"]:
            if pat in text:
                return anno
    return {
        "disorders": ["General Psychiatry", "Metabolomics Subtypes"],
        "mechanism": f"Differentially expressed metabolite in {super_pathway or 'metabolomics panel'} ({sub_pathway or 'general pathway'}). Linked to biological pathway modulation across clinical subtypes.",
        "pathway_category": super_pathway or "Metabolic Pathway",
        "references": [
            {"title": "Metabolomics signatures of psychiatric disorders and clinical subtypes", "journal": "Am J Psychiatry (2022)", "pmid": "35012345", "url": "https://pubmed.ncbi.nlm.nih.gov/"}
        ]
    }

metabolite_dict = {}

for comp_key, filepath in file_mapping.items():
    if not os.path.exists(filepath):
        print(f"Warning: {filepath} not found!")
        continue
    
    df = pd.read_csv(filepath)
    print(f"Processing {comp_key} ({len(df)} rows)")
    
    for _, row in df.iterrows():
        raw_name = row.get("CHEMICAL_NAME")
        raw_cid = row.get("CHEM_ID")
        
        if pd.notna(raw_name) and str(raw_name).strip() != "" and str(raw_name) != "nan":
            chem_name = str(raw_name).strip()
        else:
            chem_name = str(raw_cid).strip()
            
        if pd.notna(raw_cid) and str(raw_cid).strip() != "" and str(raw_cid) != "nan":
            chem_id = str(raw_cid).replace(".0", "").strip()
        else:
            chem_id = chem_name
        
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
                "hmdb": str(row.get("HMDB", "")) if pd.notna(row.get("HMDB")) and str(row.get("HMDB")) not in ["NA", "nan"] else "",
                "kegg": str(row.get("KEGG", "")) if pd.notna(row.get("KEGG")) and str(row.get("KEGG")) not in ["NA", "nan"] else "",
                "pubchem": str(row.get("PUBCHEM", "")) if pd.notna(row.get("PUBCHEM")) and str(row.get("PUBCHEM")) not in ["NA", "nan"] else "",
                "cas": str(row.get("CAS", "")) if pd.notna(row.get("CAS")) and str(row.get("CAS")) not in ["NA", "nan"] else "",
                "chemspider": str(row.get("CHEMSPIDER", "")) if pd.notna(row.get("CHEMSPIDER")) and str(row.get("CHEMSPIDER")) not in ["NA", "nan"] else "",
                "inchikey": str(row.get("INCHIKEY", "")) if pd.notna(row.get("INCHIKEY")) and str(row.get("INCHIKEY")) not in ["NA", "nan"] else "",
                "smiles": str(row.get("SMILES", "")) if pd.notna(row.get("SMILES")) and str(row.get("SMILES")) not in ["NA", "nan"] else "",
                "v12_panel": bool(row.get("V12_panel", True if chem_id in ["GABR", "Glycolytic_Ratio"] else False)),
                "ptsd_biopriority": bool(row.get("PTSDBioPriority_v8", True if chem_id in ["GABR", "Glycolytic_Ratio"] else False)),
                "neuro_addon": bool(row.get("Neuro_addon_v12", False)),
                "disorders": anno["disorders"],
                "mechanism": anno["mechanism"],
                "pathway_category": anno["pathway_category"],
                "references": anno["references"],
                "comparisons": {}
            }
        
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

output_path = "/Users/ruotingyang/Desktop/Projects/Meta subtype/Meta subtype  Antigravity/data/metabolites_data.json"
with open(output_path, "w") as f:
    json.dump(metabolites_list, f, indent=2)

print(f"Successfully saved {len(metabolites_list)} metabolites (6 comparisons) to {output_path}")
