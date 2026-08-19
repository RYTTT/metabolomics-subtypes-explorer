"use client";

import React, { useEffect, useId, useRef } from "react";
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
import { Metabolite, ComparisonKey, COMPARISON_LABELS } from "@/types/metabolite";

interface MetaboliteModalProps {
  metabolite: Metabolite | null;
  onClose: () => void;
}

const COMPARISON_SHORT_LABELS: Record<string, string> = {
  Depressive_vs_Control: "Depressive",
  Cognitive_vs_Control: "Cognitive",
  MildPTSD_vs_Control: "Mild PTSD",
  SeverePTSD_vs_Control: "Severe PTSD",
  MildPTSD_vs_SeverePTSD: "Mild vs Severe",
  CogPos_vs_CogNeg: "Cog+ vs Cog−",
};

function splitIdentifiers(value: string) {
  return value.split(/[;,]/).map((id) => id.trim()).filter(Boolean);
}

export default function MetaboliteModal({ metabolite, onClose }: MetaboliteModalProps) {
  const dialogRef = useRef<HTMLDivElement>(null);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const titleId = useId();

  useEffect(() => {
    if (!metabolite) return;

    const previouslyFocused = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const previousBodyOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const focusFrame = window.requestAnimationFrame(() => closeButtonRef.current?.focus());

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.preventDefault();
        onClose();
        return;
      }

      if (e.key !== "Tab" || !dialogRef.current) return;
      const focusable = Array.from(
        dialogRef.current.querySelectorAll<HTMLElement>(
          'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])',
        ),
      );
      if (focusable.length === 0) return;

      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    };
    document.addEventListener("keydown", handleKeyDown);

    return () => {
      window.cancelAnimationFrame(focusFrame);
      document.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = previousBodyOverflow;
      previouslyFocused?.focus();
    };
  }, [metabolite, onClose]);

  if (!metabolite) return null;

  const comparisonCount = Object.keys(COMPARISON_LABELS).length;

  const barData = Object.entries(COMPARISON_LABELS).map(([key, label]) => {
    const comp = metabolite.comparisons[key as ComparisonKey];
    const logFC = comp ? comp.logFC : 0;
    const pVal = comp ? comp["P.Value"] : 1;
    const color = comp ? comp.color : "grey";
    return {
      key,
      shortLabel: COMPARISON_SHORT_LABELS[key] ?? label,
      fullLabel: label,
      logFC: Number(logFC.toFixed(4)),
      pVal,
      color,
    };
  });

  return (
    <div
      className="modal-backdrop fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-950/80 backdrop-blur-md overflow-y-auto"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        className="relative w-full min-w-0 max-w-4xl glass-panel rounded-2xl p-4 sm:p-6 shadow-2xl border border-slate-700 my-4 sm:my-8 text-slate-100 max-h-[92vh] sm:max-h-[90vh] overflow-y-auto"
      >
        {/* Close Button */}
        <button
          ref={closeButtonRef}
          type="button"
          aria-label="Close metabolite details"
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
              <h2 id={titleId} className="text-xl sm:text-2xl font-extrabold text-white">{metabolite.chemical_name}</h2>
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
          {splitIdentifiers(metabolite.hmdb).map((hmdbId) => (
            <a
              key={hmdbId}
              href={`https://hmdb.ca/metabolites/${hmdbId}`}
              target="_blank"
              rel="noreferrer"
              className="flex items-center justify-between p-2 rounded-lg bg-slate-900/80 border border-slate-800 hover:border-cyan-500/50 text-cyan-300 transition"
            >
              <span>HMDB: <strong className="font-mono">{hmdbId}</strong></span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          ))}
          {splitIdentifiers(metabolite.kegg).map((keggId) => (
            <a
              key={keggId}
              href={`https://www.genome.jp/entry/${keggId}`}
              target="_blank"
              rel="noreferrer"
              className="flex items-center justify-between p-2 rounded-lg bg-slate-900/80 border border-slate-800 hover:border-emerald-500/50 text-emerald-300 transition"
            >
              <span>KEGG: <strong className="font-mono">{keggId}</strong></span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          ))}
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
          <div className="h-64 w-full min-w-0 glass-card rounded-xl p-2 sm:p-3" role="img" aria-label={`Fold change chart for ${metabolite.chemical_name}`}>
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={barData} margin={{ top: 15, right: 8, bottom: 48, left: -12 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#dfe5ee" />
                <XAxis dataKey="shortLabel" stroke="#65728a" fontSize={10} interval={0} angle={-25} textAnchor="end" height={58} />
                <YAxis stroke="#65728a" fontSize={11} />
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
                <ReferenceLine y={0} stroke="#94a3b8" />
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
            Differential Statistics across {comparisonCount} Comparisons
          </h3>
          <div className="w-full min-w-0 overflow-x-auto rounded-xl border border-slate-800">
            <table className="w-full min-w-[680px] text-xs text-left">
              <thead className="bg-slate-900/90 text-slate-400 border-b border-slate-800 font-semibold uppercase">
                <tr>
                  <th className="py-2.5 px-3">Comparison</th>
                  <th className="py-2.5 px-3 text-right">logFC</th>
                  <th className="py-2.5 px-3 text-right">Effect Size (d)</th>
                  <th className="py-2.5 px-3 text-right">P-value</th>
                  <th className="py-2.5 px-3 text-right">FDR (adj P)</th>
                  <th className="py-2.5 px-3 text-right">t-stat</th>
                  <th className="py-2.5 px-3 text-center">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 font-mono">
                {Object.entries(COMPARISON_LABELS).map(([key, label]) => {
                  const comp = metabolite.comparisons[key as ComparisonKey];
                  if (!comp) {
                    return (
                      <tr key={key} className="bg-slate-950/30">
                        <td className="py-2 px-3 font-sans text-slate-300 font-medium">{label}</td>
                        <td colSpan={6} className="py-2 px-3 text-center text-slate-500">Not available in this dataset release</td>
                      </tr>
                    );
                  }
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
                      <td className="py-2 px-3 text-right font-bold text-emerald-300">
                        {comp.effect_size > 0 ? "+" : ""}{comp.effect_size.toFixed(3)}
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
