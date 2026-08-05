"use client";

import React, { useState } from "react";
import { BookOpen, ExternalLink, Filter } from "lucide-react";
import { Metabolite } from "@/types/metabolite";

interface LiteratureHubProps {
  metabolites: Metabolite[];
  onSelectMetabolite: (metabolite: Metabolite) => void;
}

export default function LiteratureHub({ metabolites, onSelectMetabolite }: LiteratureHubProps) {
  const [selectedDisorder, setSelectedDisorder] = useState<string>("All");

  const DISORDER_CATEGORIES = [
    "All",
    "PTSD (Severe)",
    "MDD (Depressive Subtype)",
    "Cognitive Impairment",
    "Neuroinflammation",
    "HPA Axis Dysfunction",
    "Gut-Brain Axis",
    "Mitochondrial Energy Deficit",
  ];

  // Group metabolites by category
  const categorized = metabolites.filter((m) => {
    if (selectedDisorder === "All") return true;
    return m.disorders.some((d) => d.toLowerCase().includes(selectedDisorder.toLowerCase().split(" ")[0]));
  });

  return (
    <div className="space-y-6">
      {/* Category Selection Filter */}
      <div className="glass-panel p-4 rounded-2xl border border-slate-800 flex flex-wrap items-center gap-2">
        <span className="text-xs font-bold text-slate-400 uppercase tracking-wider mr-2 flex items-center gap-1.5">
          <Filter className="w-3.5 h-3.5 text-cyan-400" /> Filter Disorder Domain:
        </span>
        {DISORDER_CATEGORIES.map((cat) => (
          <button
            key={cat}
            onClick={() => setSelectedDisorder(cat)}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition ${
              selectedDisorder === cat
                ? "bg-cyan-500 text-slate-950 font-bold shadow-lg shadow-cyan-500/20"
                : "bg-slate-900/80 text-slate-300 hover:bg-slate-800 hover:text-white border border-slate-800"
            }`}
          >
            {cat}
          </button>
        ))}
      </div>

      {/* Grid of Literature & Mechanism Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {categorized.slice(0, 30).map((m) => {
          // Check top significant comparisons for badge display
          const sigComps = Object.entries(m.comparisons).filter(([, c]) => c["P.Value"] < 0.05);

          return (
            <div
              key={m.chem_id}
              onClick={() => onSelectMetabolite(m)}
              className="glass-card rounded-2xl p-5 border border-slate-800 hover:border-cyan-500/40 cursor-pointer transition flex flex-col justify-between group"
            >
              <div>
                <div className="flex items-start justify-between gap-2 mb-2">
                  <h4 className="text-base font-bold text-white group-hover:text-cyan-300 transition">
                    {m.chemical_name}
                  </h4>
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-slate-900 text-slate-400 border border-slate-800">
                    {m.chem_id}
                  </span>
                </div>

                <div className="flex flex-wrap gap-1.5 mb-3">
                  {m.disorders.map((d, i) => (
                    <span key={i} className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-cyan-950/70 text-cyan-300 border border-cyan-500/30">
                      {d}
                    </span>
                  ))}
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-purple-950/70 text-purple-300 border border-purple-500/30">
                    {m.pathway_category}
                  </span>
                </div>

                <p className="text-xs text-slate-300 leading-relaxed line-clamp-3 mb-4">{m.mechanism}</p>
              </div>

              <div>
                {/* Significant in comparisons badge summary */}
                {sigComps.length > 0 && (
                  <div className="mb-3 pt-3 border-t border-slate-800/80 flex flex-wrap gap-1">
                    <span className="text-[10px] text-slate-400 self-center mr-1">Significant in:</span>
                    {sigComps.map(([k, c]) => (
                      <span
                        key={k}
                        className={`px-1.5 py-0.5 rounded text-[10px] font-mono font-semibold ${
                          c.logFC > 0 ? "bg-red-950 text-red-300" : "bg-blue-950 text-blue-300"
                        }`}
                      >
                        {k.replace("_vs_Control", "").replace("_vs_CogNeg", "")}: {c.logFC > 0 ? "+" : ""}{c.logFC.toFixed(2)}
                      </span>
                    ))}
                  </div>
                )}

                {/* References summary */}
                {m.references && m.references.length > 0 && (
                  <div className="bg-slate-950/60 p-2.5 rounded-xl border border-slate-800/60 flex items-center justify-between text-xs text-indigo-300">
                    <span className="flex items-center gap-1.5 font-medium truncate">
                      <BookOpen className="w-3.5 h-3.5 text-indigo-400 flex-shrink-0" />
                      <span className="truncate">{m.references[0].title}</span>
                    </span>
                    <ExternalLink className="w-3.5 h-3.5 text-slate-400 group-hover:text-cyan-400 transition flex-shrink-0 ml-2" />
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
