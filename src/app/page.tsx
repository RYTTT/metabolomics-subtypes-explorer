"use client";

import React, { useState, useMemo } from "react";
import {
  Search,
  Download,
  RefreshCw,
  Brain,
  Activity,
  Layers,
  BookOpen,
  ArrowUpDown,
} from "lucide-react";
import rawData from "@/data/metabolites_data.json";
import { Metabolite, ComparisonKey, COMPARISON_LABELS } from "@/types/metabolite";
import VolcanoPlot from "@/components/VolcanoPlot";
import MetaboliteModal from "@/components/MetaboliteModal";
import LiteratureHub from "@/components/LiteratureHub";

const MATRIX_HEADERS: Record<ComparisonKey, { title: string; subtitle: string }> = {
  Depressive_vs_Control: { title: "MDD+ vs MDD-", subtitle: "Depressive Subtype vs Control" },
  Cognitive_vs_Control: { title: "Cognitive Subtype", subtitle: "CogPos vs Control" },
  MildPTSD_vs_Control: { title: "Mild PTSD+ vs PTSD-", subtitle: "Mild PTSD vs Control" },
  SeverePTSD_vs_Control: { title: "Severe PTSD+ vs PTSD-", subtitle: "Severe PTSD vs Control" },
  MildPTSD_vs_SeverePTSD: { title: "Mild vs Severe PTSD", subtitle: "Mild vs Severe" },
  CogPos_vs_CogNeg: { title: "CogPos vs CogNeg", subtitle: "+Cog vs -Cog" },
};

export default function Home() {
  const metabolites = rawData as Metabolite[];

  // State Management
  const [activeTab, setActiveTab] = useState<"matrix" | "volcano" | "literature">("matrix");
  const [activeComparison, setActiveComparison] = useState<ComparisonKey>("SeverePTSD_vs_Control");
  const [searchQuery, setSearchQuery] = useState<string>("");
  const [selectedSuperPathway, setSelectedSuperPathway] = useState<string>("All");
  const [selectedSigTier, setSelectedSigTier] = useState<string>("All");
  const [selectedDirection, setSelectedDirection] = useState<string>("All");
  const [v12PanelOnly, setV12PanelOnly] = useState<boolean>(false);
  const [sortColumn, setSortColumn] = useState<string>("name");
  const [sortDirection, setSortDirection] = useState<"asc" | "desc">("asc");
  const [inspectedMetabolite, setInspectedMetabolite] = useState<Metabolite | null>(null);

  // Extract list of Super Pathways
  const superPathways = useMemo(() => {
    const set = new Set<string>();
    metabolites.forEach((m) => {
      if (m.super_pathway) set.add(m.super_pathway);
    });
    return ["All", ...Array.from(set).sort()];
  }, [metabolites]);

  // Filtering Logic
  const filteredMetabolites = useMemo(() => {
    return metabolites.filter((m) => {
      // Search match
      if (searchQuery) {
        const q = searchQuery.toLowerCase();
        const matchesName = m.chemical_name.toLowerCase().includes(q);
        const matchesChemId = m.chem_id.toLowerCase().includes(q);
        const matchesHmdb = m.hmdb.toLowerCase().includes(q);
        const matchesKegg = m.kegg.toLowerCase().includes(q);
        const matchesSmiles = m.smiles.toLowerCase().includes(q);
        const matchesSubPathway = m.sub_pathway.toLowerCase().includes(q);
        if (!matchesName && !matchesChemId && !matchesHmdb && !matchesKegg && !matchesSmiles && !matchesSubPathway) {
          return false;
        }
      }

      // Super Pathway filter
      if (selectedSuperPathway !== "All" && m.super_pathway !== selectedSuperPathway) {
        return false;
      }

      // V12 Panel filter
      if (v12PanelOnly && !m.v12_panel) {
        return false;
      }

      // Check comparisons for Significance Tier and Direction filter
      const compKeys = Object.keys(COMPARISON_LABELS) as ComparisonKey[];

      if (selectedSigTier !== "All") {
        const hasTier = compKeys.some((k) => {
          const comp = m.comparisons[k];
          if (!comp) return false;
          if (selectedSigTier === "P < 0.01") return comp["P.Value"] < 0.01;
          if (selectedSigTier === "P < 0.05") return comp["P.Value"] < 0.05;
          if (selectedSigTier === "FDR < 0.1") return comp["adj.P.Val"] < 0.1;
          return true;
        });
        if (!hasTier) return false;
      }

      if (selectedDirection !== "All") {
        const hasDir = compKeys.some((k) => {
          const comp = m.comparisons[k];
          if (!comp) return false;
          if (selectedDirection === "UP") return comp.logFC > 0 && comp["P.Value"] < 0.05;
          if (selectedDirection === "DOWN") return comp.logFC < 0 && comp["P.Value"] < 0.05;
          return true;
        });
        if (!hasDir) return false;
      }

      return true;
    });
  }, [metabolites, searchQuery, selectedSuperPathway, selectedSigTier, selectedDirection, v12PanelOnly]);

  // Sorting Logic
  const sortedMetabolites = useMemo(() => {
    return [...filteredMetabolites].sort((a, b) => {
      let valA: number | string = 0;
      let valB: number | string = 0;

      if (sortColumn === "name") {
        valA = a.chemical_name.toLowerCase();
        valB = b.chemical_name.toLowerCase();
      } else if (sortColumn === "pathway") {
        valA = a.super_pathway.toLowerCase();
        valB = b.super_pathway.toLowerCase();
      } else if (sortColumn in COMPARISON_LABELS) {
        valA = a.comparisons[sortColumn]?.logFC ?? 0;
        valB = b.comparisons[sortColumn]?.logFC ?? 0;
      }

      if (valA < valB) return sortDirection === "asc" ? -1 : 1;
      if (valA > valB) return sortDirection === "asc" ? 1 : -1;
      return 0;
    });
  }, [filteredMetabolites, sortColumn, sortDirection]);

  // Sort Toggle Handler
  const handleSort = (col: string) => {
    if (sortColumn === col) {
      setSortDirection(sortDirection === "asc" ? "desc" : "asc");
    } else {
      setSortColumn(col);
      setSortDirection("desc");
    }
  };

  // CSV Export Handler
  const exportCSV = () => {
    const headers = [
      "CHEM_ID",
      "CHEMICAL_NAME",
      "SUPER_PATHWAY",
      "SUB_PATHWAY",
      "HMDB",
      "KEGG",
      "V12_PANEL",
      "Depressive_vs_Control_logFC",
      "Depressive_vs_Control_PValue",
      "Cognitive_vs_Control_logFC",
      "Cognitive_vs_Control_PValue",
      "MildPTSD_vs_Control_logFC",
      "MildPTSD_vs_Control_PValue",
      "SeverePTSD_vs_Control_logFC",
      "SeverePTSD_vs_Control_PValue",
      "MildPTSD_vs_SeverePTSD_logFC",
      "MildPTSD_vs_SeverePTSD_PValue",
      "CogPos_vs_CogNeg_logFC",
      "CogPos_vs_CogNeg_PValue",
    ];

    const rows = sortedMetabolites.map((m) => [
      `"${m.chem_id}"`,
      `"${m.chemical_name.replace(/"/g, '""')}"`,
      `"${m.super_pathway}"`,
      `"${m.sub_pathway}"`,
      `"${m.hmdb}"`,
      `"${m.kegg}"`,
      m.v12_panel ? "TRUE" : "FALSE",
      m.comparisons.Depressive_vs_Control?.logFC ?? "",
      m.comparisons.Depressive_vs_Control?.["P.Value"] ?? "",
      m.comparisons.Cognitive_vs_Control?.logFC ?? "",
      m.comparisons.Cognitive_vs_Control?.["P.Value"] ?? "",
      m.comparisons.MildPTSD_vs_Control?.logFC ?? "",
      m.comparisons.MildPTSD_vs_Control?.["P.Value"] ?? "",
      m.comparisons.SeverePTSD_vs_Control?.logFC ?? "",
      m.comparisons.SeverePTSD_vs_Control?.["P.Value"] ?? "",
      m.comparisons.MildPTSD_vs_SeverePTSD?.logFC ?? "",
      m.comparisons.MildPTSD_vs_SeverePTSD?.["P.Value"] ?? "",
      m.comparisons.CogPos_vs_CogNeg?.logFC ?? "",
      m.comparisons.CogPos_vs_CogNeg?.["P.Value"] ?? "",
    ]);

    const csvContent = "data:text/csv;charset=utf-8," + [headers.join(","), ...rows.map((e) => e.join(","))].join("\n");
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `metabolites_cross_comparison_v12.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // Reset Filters
  const resetFilters = () => {
    setSearchQuery("");
    setSelectedSuperPathway("All");
    setSelectedSigTier("All");
    setSelectedDirection("All");
    setV12PanelOnly(false);
  };

  return (
    <main className="min-h-screen bg-slate-950 text-slate-100 p-4 md:p-8 space-y-6 max-w-7xl mx-auto">
      {/* Top Banner & Header */}
      <header className="glass-panel p-6 rounded-3xl border border-slate-800 shadow-2xl relative overflow-hidden">
        <div className="absolute -right-10 -top-10 w-72 h-72 bg-cyan-500/10 rounded-full blur-3xl pointer-events-none"></div>
        <div className="absolute -left-10 -bottom-10 w-72 h-72 bg-purple-500/10 rounded-full blur-3xl pointer-events-none"></div>

        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-6 relative z-10">
          <div>
            <div className="flex items-center gap-2 mb-2">
              <span className="px-3 py-1 rounded-full text-xs font-bold bg-cyan-950 text-cyan-400 border border-cyan-500/40 flex items-center gap-1.5">
                <Brain className="w-3.5 h-3.5" /> Psychiatric Metabolomics Explorer
              </span>
              <span className="px-3 py-1 rounded-full text-xs font-bold bg-emerald-950 text-emerald-400 border border-emerald-500/40">
                v12 Differential Panel
              </span>
              <span className="px-3 py-1 rounded-full text-xs font-bold bg-purple-950 text-purple-300 border border-purple-500/40">
                MDD+ vs MDD- &amp; CogPos vs CogNeg
              </span>
            </div>
            <h1 className="text-3xl md:text-4xl font-extrabold text-white tracking-tight">
              Differentially Expressed Metabolites Portal
            </h1>
            <p className="text-slate-400 text-sm mt-1 max-w-3xl">
              Cross-compare, search, and inspect 386 metabolites across 6 clinical subtype comparisons including <strong>MDD+ vs MDD-</strong>, <strong>CogPos vs CogNeg</strong>, <strong>Cognitive Subtype</strong>, and <strong>Mild/Severe PTSD</strong> with biological annotations &amp; literature references.
            </p>
          </div>

          {/* Action Buttons */}
          <div className="flex items-center gap-3">
            <button
              onClick={exportCSV}
              className="px-4 py-2.5 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold text-xs flex items-center gap-2 shadow-lg shadow-cyan-500/20 transition cursor-pointer"
            >
              <Download className="w-4 h-4" /> Download CSV
            </button>
          </div>
        </div>

        {/* Quick Stats Grid */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-6 pt-6 border-t border-slate-800/80">
          <div className="glass-card p-3.5 rounded-xl border border-slate-800">
            <p className="text-xs text-slate-400 font-medium">Total Metabolites</p>
            <p className="text-2xl font-extrabold text-white mt-0.5">{metabolites.length}</p>
          </div>
          <div className="glass-card p-3.5 rounded-xl border border-slate-800">
            <p className="text-xs text-slate-400 font-medium">Significant Hits (P &lt; 0.01)</p>
            <p className="text-2xl font-extrabold text-amber-400 mt-0.5">57</p>
          </div>
          <div className="glass-card p-3.5 rounded-xl border border-slate-800">
            <p className="text-xs text-slate-400 font-medium">FDR &lt; 0.1 Discoveries</p>
            <p className="text-2xl font-extrabold text-cyan-400 mt-0.5">14</p>
          </div>
          <div className="glass-card p-3.5 rounded-xl border border-slate-800">
            <p className="text-xs text-slate-400 font-medium">Filtered Selection</p>
            <p className="text-2xl font-extrabold text-emerald-400 mt-0.5">{filteredMetabolites.length}</p>
          </div>
        </div>
      </header>

      {/* Global Filter Bar */}
      <section className="glass-panel p-4 rounded-2xl border border-slate-800 space-y-4">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3">
          {/* Search Box */}
          <div className="relative col-span-1 sm:col-span-2">
            <Search className="w-4 h-4 absolute left-3.5 top-3 text-slate-400" />
            <input
              type="text"
              placeholder="Search by metabolite name, HMDB, KEGG, SMILES..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full bg-slate-900/90 border border-slate-800 focus:border-cyan-500/60 text-slate-200 text-xs rounded-xl pl-10 pr-4 py-2.5 outline-none transition"
            />
          </div>

          {/* Super Pathway Filter */}
          <div>
            <select
              value={selectedSuperPathway}
              onChange={(e) => setSelectedSuperPathway(e.target.value)}
              className="w-full bg-slate-900/90 border border-slate-800 focus:border-cyan-500/60 text-slate-200 text-xs rounded-xl px-3 py-2.5 outline-none transition cursor-pointer"
            >
              <option value="All">Super Pathway: All</option>
              {superPathways.filter((p) => p !== "All").map((p) => (
                <option key={p} value={p}>
                  {p}
                </option>
              ))}
            </select>
          </div>

          {/* Significance Tier Filter */}
          <div>
            <select
              value={selectedSigTier}
              onChange={(e) => setSelectedSigTier(e.target.value)}
              className="w-full bg-slate-900/90 border border-slate-800 focus:border-cyan-500/60 text-slate-200 text-xs rounded-xl px-3 py-2.5 outline-none transition cursor-pointer"
            >
              <option value="All">P-value Filter: All</option>
              <option value="P < 0.05">P &lt; 0.05 (Any Comparison)</option>
              <option value="P < 0.01">P &lt; 0.01 (High Significance)</option>
              <option value="FDR < 0.1">FDR &lt; 0.1 (Strict Control)</option>
            </select>
          </div>

          {/* Direction Filter */}
          <div>
            <select
              value={selectedDirection}
              onChange={(e) => setSelectedDirection(e.target.value)}
              className="w-full bg-slate-900/90 border border-slate-800 focus:border-cyan-500/60 text-slate-200 text-xs rounded-xl px-3 py-2.5 outline-none transition cursor-pointer"
            >
              <option value="All">Direction: All</option>
              <option value="UP">Upregulated (Red)</option>
              <option value="DOWN">Downregulated (Blue)</option>
            </select>
          </div>
        </div>

        {/* Toggles & Reset */}
        <div className="flex flex-wrap items-center justify-between gap-3 pt-2 border-t border-slate-800/60 text-xs">
          <div className="flex items-center gap-4">
            <label className="flex items-center gap-2 cursor-pointer text-slate-300 hover:text-white">
              <input
                type="checkbox"
                checked={v12PanelOnly}
                onChange={(e) => setV12PanelOnly(e.target.checked)}
                className="rounded bg-slate-900 border-slate-700 text-cyan-500 focus:ring-0"
              />
              <span className="font-medium">Show v12 Biomarker Panel Only</span>
            </label>
          </div>

          <button
            onClick={resetFilters}
            className="text-slate-400 hover:text-cyan-400 flex items-center gap-1.5 transition text-xs"
          >
            <RefreshCw className="w-3.5 h-3.5" /> Reset Filters
          </button>
        </div>
      </section>

      {/* Navigation Tabs */}
      <div className="flex flex-wrap items-center gap-2 border-b border-slate-800 pb-2">
        <button
          onClick={() => setActiveTab("matrix")}
          className={`px-4 py-2.5 rounded-xl font-bold text-xs flex items-center gap-2 transition cursor-pointer ${
            activeTab === "matrix"
              ? "bg-cyan-500 text-slate-950 shadow-lg shadow-cyan-500/20"
              : "bg-slate-900/80 text-slate-400 hover:text-white hover:bg-slate-800"
          }`}
        >
          <Layers className="w-4 h-4" /> Cross-Comparison Matrix (6 Comparisons Side-by-Side)
        </button>

        <button
          onClick={() => setActiveTab("volcano")}
          className={`px-4 py-2.5 rounded-xl font-bold text-xs flex items-center gap-2 transition cursor-pointer ${
            activeTab === "volcano"
              ? "bg-cyan-500 text-slate-950 shadow-lg shadow-cyan-500/20"
              : "bg-slate-900/80 text-slate-400 hover:text-white hover:bg-slate-800"
          }`}
        >
          <Activity className="w-4 h-4" /> Volcano Plot Explorer (MDD+, PTSD+ &amp; Subtypes)
        </button>

        <button
          onClick={() => setActiveTab("literature")}
          className={`px-4 py-2.5 rounded-xl font-bold text-xs flex items-center gap-2 transition cursor-pointer ${
            activeTab === "literature"
              ? "bg-cyan-500 text-slate-950 shadow-lg shadow-cyan-500/20"
              : "bg-slate-900/80 text-slate-400 hover:text-white hover:bg-slate-800"
          }`}
        >
          <BookOpen className="w-4 h-4" /> Psychiatric Annotations &amp; PubMed Literature
        </button>
      </div>

      {/* TAB 1: Cross-Comparison Heat Matrix */}
      {activeTab === "matrix" && (
        <section className="glass-panel rounded-2xl p-4 border border-slate-800 space-y-4">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2">
            <p className="text-xs text-slate-400">
              Displaying <strong className="text-white">{sortedMetabolites.length}</strong> metabolites across all 6 comparisons. Click any column header to sort by logFC. Click any row for full annotation.
            </p>
          </div>

          <div className="overflow-x-auto rounded-xl border border-slate-800">
            <table className="w-full text-xs text-left">
              <thead className="bg-slate-900 text-slate-300 font-bold uppercase border-b border-slate-800 select-none">
                <tr>
                  <th
                    onClick={() => handleSort("name")}
                    className="py-3 px-4 cursor-pointer hover:text-cyan-400 transition"
                  >
                    <div className="flex items-center gap-1">
                      Metabolite Name <ArrowUpDown className="w-3 h-3 text-slate-500" />
                    </div>
                  </th>
                  <th
                    onClick={() => handleSort("pathway")}
                    className="py-3 px-3 cursor-pointer hover:text-cyan-400 transition"
                  >
                    <div className="flex items-center gap-1">
                      Super Pathway <ArrowUpDown className="w-3 h-3 text-slate-500" />
                    </div>
                  </th>
                  {Object.entries(COMPARISON_LABELS).map(([key]) => {
                    const headerInfo = MATRIX_HEADERS[key as ComparisonKey] || { title: key, subtitle: "" };
                    return (
                      <th
                        key={key}
                        onClick={() => handleSort(key)}
                        className="py-3 px-3 text-center cursor-pointer hover:text-cyan-400 transition min-w-[120px]"
                      >
                        <div className="flex flex-col items-center">
                          <span>{headerInfo.title}</span>
                          <span className="text-[9px] text-slate-500 font-normal">
                            {headerInfo.subtitle}
                          </span>
                        </div>
                      </th>
                    );
                  })}
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 font-mono">
                {sortedMetabolites.map((m) => (
                  <tr
                    key={m.chem_id}
                    onClick={() => setInspectedMetabolite(m)}
                    className="hover:bg-slate-900/70 cursor-pointer transition group"
                  >
                    <td className="py-2.5 px-4 font-sans font-semibold text-slate-200 group-hover:text-cyan-300">
                      <div className="flex items-center gap-2">
                        <span>{m.chemical_name}</span>
                        {m.v12_panel && (
                          <span className="px-1.5 py-0.5 rounded text-[9px] font-bold bg-emerald-950 text-emerald-400 border border-emerald-500/40">
                            v12
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="py-2.5 px-3 font-sans text-slate-400 text-[11px] truncate max-w-[140px]">
                      {m.super_pathway}
                    </td>

                    {/* 6 Comparative Columns */}
                    {(Object.keys(COMPARISON_LABELS) as ComparisonKey[]).map((key) => {
                      const comp = m.comparisons[key];
                      if (!comp) return <td key={key} className="text-center text-slate-600">-</td>;

                      const isSig01 = comp["P.Value"] < 0.01;
                      const isSig05 = comp["P.Value"] < 0.05;

                      return (
                        <td key={key} className="py-2.5 px-2 text-center">
                          <span
                            className={`inline-block px-2 py-1 rounded text-[11px] font-bold ${
                              comp.color === "red"
                                ? isSig01
                                  ? "bg-red-500/20 text-red-400 border border-red-500/50 shadow-sm"
                                  : "bg-red-950/60 text-red-400"
                                : comp.color === "blue"
                                ? isSig01
                                  ? "bg-blue-500/20 text-blue-400 border border-blue-500/50 shadow-sm"
                                  : "bg-blue-950/60 text-blue-400"
                                : "text-slate-500 font-normal"
                            }`}
                          >
                            {comp.logFC > 0 ? "+" : ""}
                            {comp.logFC.toFixed(2)}
                            {isSig01 ? "*" : isSig05 ? "°" : ""}
                          </span>
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      {/* TAB 2: Single Comparison Volcano Plot */}
      {activeTab === "volcano" && (
        <div className="space-y-6">
          {/* Subtype Selector */}
          <div className="glass-panel p-4 rounded-2xl border border-slate-800 flex flex-wrap items-center gap-3">
            <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">Select Comparison:</span>
            {(Object.keys(COMPARISON_LABELS) as ComparisonKey[]).map((k) => (
              <button
                key={k}
                onClick={() => setActiveComparison(k)}
                className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition cursor-pointer ${
                  activeComparison === k
                    ? "bg-cyan-500 text-slate-950 shadow-lg shadow-cyan-500/20"
                    : "bg-slate-900/80 text-slate-400 hover:text-white border border-slate-800"
                }`}
              >
                {COMPARISON_LABELS[k]}
              </button>
            ))}
          </div>

          {/* Volcano Plot Component */}
          <VolcanoPlot
            metabolites={filteredMetabolites}
            activeComparison={activeComparison}
            onSelectMetabolite={(m) => setInspectedMetabolite(m)}
          />
        </div>
      )}

      {/* TAB 3: Psychiatric Literature & Annotations */}
      {activeTab === "literature" && (
        <LiteratureHub
          metabolites={filteredMetabolites}
          onSelectMetabolite={(m) => setInspectedMetabolite(m)}
        />
      )}

      {/* Metabolite Detail Modal */}
      <MetaboliteModal
        metabolite={inspectedMetabolite}
        onClose={() => setInspectedMetabolite(null)}
      />
    </main>
  );
}
