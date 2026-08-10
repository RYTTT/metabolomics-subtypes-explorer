export interface Reference {
  title: string;
  journal: string;
  pmid: string;
  url: string;
}

export interface ComparisonStats {
  logFC: number;
  "P.Value": number;
  "adj.P.Val": number;
  t: number;
  AveExpr: number;
  B: number;
  color: "red" | "blue" | "grey";
  direction: "UP" | "DOWN" | "NC";
  p_tier: "FDR < 0.1" | "P < 0.01" | "P < 0.05" | "NS";
}

export interface Metabolite {
  chem_id: string;
  chemical_name: string;
  plot_name: string;
  super_pathway: string;
  sub_pathway: string;
  hmdb: string;
  kegg: string;
  pubchem: string;
  cas: string;
  chemspider: string;
  inchikey: string;
  smiles: string;
  v12_panel: boolean;
  ptsd_biopriority: boolean;
  neuro_addon: boolean;
  disorders: string[];
  mechanism: string;
  pathway_category: string;
  references: Reference[];
  comparisons: Partial<Record<ComparisonKey, ComparisonStats>>;
}

export type ComparisonKey =
  | "Depressive_vs_Control"
  | "Cognitive_vs_Control"
  | "MildPTSD_vs_Control"
  | "SeverePTSD_vs_Control"
  | "MildPTSD_vs_SeverePTSD"
  | "CogPos_vs_CogNeg";

export const COMPARISON_LABELS: Record<ComparisonKey, string> = {
  Depressive_vs_Control: "MDD+ vs MDD-",
  Cognitive_vs_Control: "Cognitive Subtype vs Control",
  MildPTSD_vs_Control: "Mild PTSD+ vs PTSD-",
  SeverePTSD_vs_Control: "Severe PTSD+ vs PTSD-",
  MildPTSD_vs_SeverePTSD: "Mild PTSD vs Severe PTSD",
  CogPos_vs_CogNeg: "CogPos vs CogNeg",
};
