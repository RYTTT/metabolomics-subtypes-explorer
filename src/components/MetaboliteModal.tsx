"use client";

import React from "react";
import {
  X,
  ExternalLink,
  BookOpen,
  Brain,
  Dna,
  Layers,
  Activity,
} from "lucide-react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Cell,
  ReferenceLine,
} from "recharts";
import { Metabolite, COMPARISON_LABELS } from "@/types/metabolite";

interface MetaboliteModalProps {
  metabolite: Metabolite | null;
  onClose: () => void;
}

export default function MetaboliteModal({ metabolite, onClose }: MetaboliteModalProps) {
  if (!metabolite) return null;

  const barData = Object.entries(COMPARISON_LABELS).map(([key, label]) => {
    const comp = metabolite.comparisons[key];
    const logFC = comp ? comp.logFC : 0;
    const pVal = comp ? comp["P.Value"] : 1;
    const color = comp ? comp.color : "grey";
    return {
      key,
      shortLabel: key.replace("_vs_", " v ").replace("Control", "Ctrl"),
      fullLabel: label,
      logFC: Number(logFC.toFixed(4)),
      pVal,
      color,
    };
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md overflow-y-auto">
      <div className="relative w-full max-w-4xl glass-panel rounded-2xl p-6 shadow-2xl border border-slate-700 my-8 text-slate-100 max-h-[90vh] overflow-y-auto">
        {/* Close Button */}
        <button
          onClick={onClose}
          className="absolute top-5 right-5 p-2 rounded-full bg-slate-800/80 text-slate-400 hover:text-white hover:bg-slate-700 transition"
        >
          <X className="w-5 h-5" />
        </button>

        {/* Header */}
        <div className="flex flex-col sm:flex-row items-start sm:items-center gap-3 pr-10 border-b border-slate-800 pb-4">
          <div className="p-3 rounded-xl bg-cyan-950/60 border border-cyan-500/30 text-cyan-400">
            <Brain className="w-7 h-7" />
          </div>
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-2xl font-extrabold text-white">{metabolite.chemical_name}</h2>
              {metabolite.v12_panel && (
                <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-950 text-emerald-400 border border-emerald-500/40">
                  v12 Biomarker Panel
                </span>
              )}
              {metabolite.ptsd_biopriority && (
                <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-purple-950 text-purple-300 border border-purple-500/40">
                  PTSD BioPriority
                </span>
              )}
            </div>
            <p className="text-xs text-slate-400 mt-1 flex flex-wrap items-center gap-3">
              <span>Super Pathway: <strong className="text-slate-200">{metabolite.super_pathway}</strong></span>
              <span>•</span>
              <span>Sub Pathway: <strong className="text-slate-200">{metabolite.sub_pathway}</strong></span>
              <span>•</span>
              <span>ID: <strong className="font-mono text-cyan-400">{metabolite.chem_id}</strong></span>
            </p>
          </div>
        </div>

        {/* Database Links & Identifiers */}
        <div className="my-4 grid grid-cols-2 sm:grid-cols-4 gap-2 text-xs">
          {metabolite.hmdb && (
            <a
              href={`https://hmdb.ca/metabolites/${metabolite.hmdb}`}
              target="_blank"
              rel="noreferrer"
              className="flex items-center justify-between p-2 rounded-lg bg-slate-900/80 border border-slate-800 hover:border-cyan-500/50 text-cyan-300 transition"
            >
              <span>HMDB: <strong className="font-mono">{metabolite.hmdb}</strong></span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          )}
          {metabolite.kegg && (
            <a
              href={`https://www.genome.jp/entry/${metabolite.kegg}`}
              target="_blank"
              rel="noreferrer"
              className="flex items-center justify-between p-2 rounded-lg bg-slate-900/80 border border-slate-800 hover:border-emerald-500/50 text-emerald-300 transition"
            >
              <span>KEGG: <strong className="font-mono">{metabolite.kegg}</strong></span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          )}
          {metabolite.pubchem && (
            <a
              href={`https://pubchem.ncbi.nlm.nih.gov/compound/${metabolite.pubchem}`}
              target="_blank"
              rel="noreferrer"
              className="flex items-center justify-between p-2 rounded-lg bg-slate-900/80 border border-slate-800 hover:border-indigo-500/50 text-indigo-300 transition"
            >
              <span>PubChem: <strong className="font-mono">{metabolite.pubchem}</strong></span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          )}
          {metabolite.smiles && (
            <div className="col-span-2 sm:col-span-4 p-2 rounded-lg bg-slate-900/90 border border-slate-800 font-mono text-[11px] text-slate-300 truncate">
              <span className="text-slate-500 mr-2">SMILES:</span>
              {metabolite.smiles}
            </div>
          )}
        </div>

        {/* Section 1: Comparative LogFC Bar Chart */}
        <div className="mt-6">
          <h3 className="text-sm font-bold text-slate-300 uppercase tracking-wider mb-3 flex items-center gap-2">
            <Activity className="w-4 h-4 text-cyan-400" />
            Comparative Log2 Fold Change across Subtypes
          </h3>
          <div className="h-56 w-full glass-card rounded-xl p-3">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={barData} margin={{ top: 15, right: 15, bottom: 25, left: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
                <XAxis dataKey="shortLabel" stroke="#94a3b8" fontSize={11} interval={0} />
                <YAxis stroke="#94a3b8" fontSize={11} />
                <Tooltip
                  content={({ payload }) => {
                    if (payload && payload.length) {
                      const pt = payload[0].payload;
                      return (
                        <div className="glass-panel p-2.5 rounded-lg border border-slate-700 text-xs">
                          <p className="font-semibold text-white">{pt.fullLabel}</p>
                          <p className="text-cyan-300 mt-1">logFC: <span className="font-mono font-bold">{pt.logFC}</span></p>
                          <p className="text-amber-300">P-value: <span className="font-mono">{pt.pVal.toExponential(3)}</span></p>
                        </div>
                      );
                    }
                    return null;
                  }}
                />
                <ReferenceLine y={0} stroke="#475569" />
                <Bar dataKey="logFC" radius={[4, 4, 0, 0]}>
                  {barData.map((entry, index) => (
                    <Cell
                      key={`cell-${index}`}
                      fill={entry.color === "red" ? "#ef4444" : entry.color === "blue" ? "#3b82f6" : "#64748b"}
                    />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Section 2: Complete Stats Table */}
        <div className="mt-6">
          <h3 className="text-sm font-bold text-slate-300 uppercase tracking-wider mb-3 flex items-center gap-2">
            <Layers className="w-4 h-4 text-cyan-400" />
            Differential Statistics across 7 Comparisons
          </h3>
          <div className="overflow-x-auto rounded-xl border border-slate-800">
            <table className="w-full text-xs text-left">
              <thead className="bg-slate-900/90 text-slate-400 border-b border-slate-800 font-semibold uppercase">
                <tr>
                  <th className="py-2.5 px-3">Comparison</th>
                  <th className="py-2.5 px-3 text-right">logFC</th>
                  <th className="py-2.5 px-3 text-right">P-value</th>
                  <th className="py-2.5 px-3 text-right">FDR (adj P)</th>
                  <th className="py-2.5 px-3 text-right">t-stat</th>
                  <th className="py-2.5 px-3 text-center">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 font-mono">
                {Object.entries(COMPARISON_LABELS).map(([key, label]) => {
                  const comp = metabolite.comparisons[key];
                  if (!comp) return null;
                  return (
                    <tr key={key} className="hover:bg-slate-900/50 transition">
                      <td className="py-2 px-3 font-sans text-slate-300 font-medium">{label}</td>
                      <td
                        className={`py-2 px-3 text-right font-bold ${
                          comp.logFC > 0 ? "text-red-400" : comp.logFC < 0 ? "text-blue-400" : "text-slate-400"
                        }`}
                      >
                        {comp.logFC.toFixed(4)}
                      </td>
                      <td className={`py-2 px-3 text-right ${comp["P.Value"] < 0.01 ? "text-amber-400 font-bold" : "text-slate-300"}`}>
                        {comp["P.Value"].toExponential(3)}
                      </td>
                      <td className="py-2 px-3 text-right text-indigo-300">{comp["adj.P.Val"].toExponential(3)}</td>
                      <td className="py-2 px-3 text-right text-slate-400">{comp.t.toFixed(3)}</td>
                      <td className="py-2 px-3 text-center">
                        <span
                          className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                            comp.color === "red"
                              ? "bg-red-950 text-red-300 border border-red-500/40"
                              : comp.color === "blue"
                              ? "bg-blue-950 text-blue-300 border border-blue-500/40"
                              : "bg-slate-800 text-slate-400"
                          }`}
                        >
                          {comp.direction}
                        </span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>

        {/* Section 3: Biological Mechanism & Psychiatric Literature References */}
        <div className="mt-6 border-t border-slate-800 pt-5">
          <div className="flex items-center gap-2 text-cyan-300 mb-3">
            <Dna className="w-5 h-5" />
            <h3 className="text-base font-bold text-white">Biological Mechanism &amp; Psychiatric Disorder Relevance</h3>
          </div>

          <div className="glass-card rounded-xl p-4 mb-4 border-l-4 border-l-cyan-500">
            <div className="flex flex-wrap gap-2 mb-2">
              {metabolite.disorders.map((d, i) => (
                <span key={i} className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-cyan-950/80 text-cyan-300 border border-cyan-500/30">
                  {d}
                </span>
              ))}
              <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-purple-950/80 text-purple-300 border border-purple-500/30">
                {metabolite.pathway_category}
              </span>
            </div>
            <p className="text-sm text-slate-300 leading-relaxed">{metabolite.mechanism}</p>
          </div>

          {/* Academic References */}
          {metabolite.references && metabolite.references.length > 0 && (
            <div>
              <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                <BookOpen className="w-3.5 h-3.5 text-indigo-400" />
                Key Literature &amp; PubMed Citations
              </h4>
              <div className="space-y-2">
                {metabolite.references.map((ref, idx) => (
                  <a
                    key={idx}
                    href={ref.url}
                    target="_blank"
                    rel="noreferrer"
                    className="group block p-3 rounded-lg bg-slate-900/70 border border-slate-800 hover:border-indigo-500/60 transition"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <p className="text-xs font-semibold text-slate-200 group-hover:text-cyan-300 transition">
                          {ref.title}
                        </p>
                        <p className="text-[11px] text-slate-400 mt-0.5">
                          {ref.journal} — PMID: <span className="font-mono text-indigo-300">{ref.pmid}</span>
                        </p>
                      </div>
                      <ExternalLink className="w-4 h-4 text-slate-500 group-hover:text-cyan-400 transition flex-shrink-0 mt-0.5" />
                    </div>
                  </a>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
