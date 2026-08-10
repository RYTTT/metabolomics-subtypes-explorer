"use client";

import React, { useState, useMemo, useCallback, useEffect } from "react";
import {
  Search,
  Download,
  RefreshCw,
  Brain,
  Activity,
  Layers,
  BookOpen,
  ArrowUpDown,
  ChevronUp,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";
import rawData from "@/data/metabolites_data.json";
import { Metabolite, ComparisonKey, COMPARISON_LABELS } from "@/types/metabolite";
import VolcanoPlot from "@/components/VolcanoPlot";
import MetaboliteModal from "@/components/MetaboliteModal";
import LiteratureHub from "@/components/LiteratureHub";
import release from "@/data/release.json";

const MATRIX_HEADERS: Record<ComparisonKey, { title: string; subtitle: string }> = {
  Depressive_vs_Control: { title: "MDD+ vs MDD-", subtitle: "Depressive Subtype vs Control" },
  Cognitive_vs_Control: { title: "Cognitive Subtype", subtitle: "CogPos vs Control" },
  MildPTSD_vs_Control: { title: "Mild PTSD+ vs PTSD-", subtitle: "Mild PTSD vs Control" },
  SeverePTSD_vs_Control: { title: "Severe PTSD+ vs PTSD-", subtitle: "Severe PTSD vs Control" },
  MildPTSD_vs_SeverePTSD: { title: "Mild vs Severe PTSD", subtitle: "Mild vs Severe" },
  CogPos_vs_CogNeg: { title: "CogPos vs CogNeg", subtitle: "+Cog vs -Cog" },
};

const ROWS_PER_PAGE = 50;

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
  const [currentPage, setCurrentPage] = useState<number>(1);
  const closeModal = useCallback(() => setInspectedMetabolite(null), []);

  // Debounced search
  const [debouncedQuery, setDebouncedQuery] = useState<string>("");
  const debounceTimerRef = React.useRef<ReturnType<typeof setTimeout> | null>(null);
  const handleSearchChange = useCallback((value: string) => {
    setSearchQuery(value);
    if (debounceTimerRef.current) clearTimeout(debounceTimerRef.current);
    debounceTimerRef.current = setTimeout(() => {
      setDebouncedQuery(value);
      setCurrentPage(1);
    }, 300);
  }, []);

  useEffect(() => {
    return () => {
      if (debounceTimerRef.current) clearTimeout(debounceTimerRef.current);
    };
  }, []);

  // Extract list of Super Pathways
  const superPathways = useMemo(() => {
    const set = new Set<string>();
    metabolites.forEach((m) => {
      if (m.super_pathway) set.add(m.super_pathway);
    });
    return ["All", ...Array.from(set).sort()];
  }, [metabolites]);

  const hasV12Subset = useMemo(
    () => metabolites.some((m) => m.v12_panel) && metabolites.some((m) => !m.v12_panel),
    [metabolites],
  );

  // Dynamically computed stats
  const stats = useMemo(() => {
    const compKeys = Object.keys(COMPARISON_LABELS) as ComparisonKey[];
    const sig01Set = new Set<string>();
    const fdr01Set = new Set<string>();
    metabolites.forEach((m) => {
      compKeys.forEach((k) => {
        const comp = m.comparisons[k];
        if (!comp) return;
        if (comp["P.Value"] < 0.01) sig01Set.add(m.chem_id);
        if (comp["adj.P.Val"] < 0.1) fdr01Set.add(m.chem_id);
      });
    });
    return { sig01: sig01Set.size, fdr01: fdr01Set.size };
  }, [metabolites]);

  // Filtering Logic
  const filteredMetabolites = useMemo(() => {
    return metabolites.filter((m) => {
      // Search match (uses debounced query)
      if (debouncedQuery) {
        const q = debouncedQuery.toLowerCase();
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
  }, [metabolites, debouncedQuery, selectedSuperPathway, selectedSigTier, selectedDirection, v12PanelOnly]);

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
        valA = a.comparisons[sortColumn as ComparisonKey]?.logFC ?? 0;
        valB = b.comparisons[sortColumn as ComparisonKey]?.logFC ?? 0;
      }

      if (valA < valB) return sortDirection === "asc" ? -1 : 1;
      if (valA > valB) return sortDirection === "asc" ? 1 : -1;
      return 0;
    });
  }, [filteredMetabolites, sortColumn, sortDirection]);

  // Pagination
  const totalPages = Math.max(1, Math.ceil(sortedMetabolites.length / ROWS_PER_PAGE));
  const paginatedMetabolites = useMemo(() => {
    const start = (currentPage - 1) * ROWS_PER_PAGE;
    return sortedMetabolites.slice(start, start + ROWS_PER_PAGE);
  }, [sortedMetabolites, currentPage]);

  // Sort Toggle Handler
  const handleSort = (col: string) => {
    if (sortColumn === col) {
      setSortDirection(sortDirection === "asc" ? "desc" : "asc");
    } else {
      setSortColumn(col);
      setSortDirection("desc");
    }
    setCurrentPage(1);
  };

  const handleTabKeyDown = (event: React.KeyboardEvent<HTMLButtonElement>) => {
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
    const tabs = Array.from(
      event.currentTarget.parentElement?.querySelectorAll<HTMLButtonElement>('[role="tab"]') ?? [],
    );
    if (tabs.length === 0) return;
    event.preventDefault();
    const currentIndex = tabs.indexOf(event.currentTarget);
    const nextIndex = event.key === "Home"
      ? 0
      : event.key === "End"
        ? tabs.length - 1
        : (currentIndex + (event.key === "ArrowRight" ? 1 : -1) + tabs.length) % tabs.length;
    tabs[nextIndex].focus();
    tabs[nextIndex].click();
  };

  // Sort indicator helper (not a component — returns JSX directly)
  const sortIcon = (col: string) => {
    if (sortColumn !== col) return <ArrowUpDown className="w-3 h-3 text-slate-500" />;
    return sortDirection === "asc" ? <ChevronUp className="w-3 h-3 text-cyan-400" /> : <ChevronDown className="w-3 h-3 text-cyan-400" />;
  };

  // CSV Export Handler (includes FDR)
  const exportCSV = () => {
    const compKeys = Object.keys(COMPARISON_LABELS) as ComparisonKey[];
    const headers = [
      "CHEM_ID",
      "CHEMICAL_NAME",
      "SUPER_PATHWAY",
      "SUB_PATHWAY",
      "HMDB",
      "KEGG",
      "V12_PANEL",
      ...compKeys.flatMap((k) => [`${k}_logFC`, `${k}_PValue`, `${k}_adjPVal`]),
    ];

    const csvCell = (value: string | number | boolean) => `"${String(value).replace(/"/g, '""')}"`;
    const rows = sortedMetabolites.map((m) => [
      csvCell(m.chem_id),
      csvCell(m.chemical_name),
      csvCell(m.super_pathway),
      csvCell(m.sub_pathway),
      csvCell(m.hmdb),
      csvCell(m.kegg),
      m.v12_panel ? "TRUE" : "FALSE",
      ...compKeys.flatMap((k) => {
        const c = m.comparisons[k];
        return [c?.logFC ?? "", c?.["P.Value"] ?? "", c?.["adj.P.Val"] ?? ""];
      }),
    ]);

    const csvContent = [headers.join(","), ...rows.map((e) => e.join(","))].join("\n");
    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8" });
    const objectUrl = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", objectUrl);
    link.setAttribute("download", `metabolites_cross_comparison_v12.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(objectUrl);
  };

  // Reset Filters
  const resetFilters = () => {
    setSearchQuery("");
    setDebouncedQuery("");
    setSelectedSuperPathway("All");
    setSelectedSigTier("All");
    setSelectedDirection("All");
    setV12PanelOnly(false);
    setCurrentPage(1);
  };

  return (
    <main className="min-h-screen w-full min-w-0 overflow-x-hidden bg-slate-950 text-slate-100 p-4 md:p-8 space-y-6 max-w-7xl mx-auto">
      {/* Top Banner & Header */}
      <header className="glass-panel p-6 rounded-3xl border border-slate-800 shadow-2xl relative overflow-hidden">
        <div className="absolute -right-10 -top-10 w-72 h-72 bg-cyan-500/10 rounded-full blur-3xl pointer-events-none"></div>
        <div className="absolute -left-10 -bottom-10 w-72 h-72 bg-purple-500/10 rounded-full blur-3xl pointer-events-none"></div>

        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-6 relative z-10">
          <div>
            <div className="flex flex-wrap items-center gap-2 mb-2">
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
              Cross-compare, search, and inspect {metabolites.length} metabolites across {Object.keys(COMPARISON_LABELS).length} clinical subtype comparisons including <strong>MDD+ vs MDD-</strong>, <strong>CogPos vs CogNeg</strong>, <strong>Cognitive Subtype</strong>, and <strong>Mild/Severe PTSD</strong> with biological annotations &amp; literature references.
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

        {/* Quick Stats Grid — all dynamically computed */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-6 pt-6 border-t border-slate-800/80">
          <div className="glass-card p-3.5 rounded-xl border border-slate-800">
            <p className="text-xs text-slate-400 font-medium">Total Metabolites</p>
            <p className="text-2xl font-extrabold text-white mt-0.5">{metabolites.length}</p>
          </div>
          <div className="glass-card p-3.5 rounded-xl border border-slate-800">
            <p className="text-xs text-slate-400 font-medium">Significant Hits (P &lt; 0.01)</p>
            <p className="text-2xl font-extrabold text-amber-400 mt-0.5">{stats.sig01}</p>
          </div>
          <div className="glass-card p-3.5 rounded-xl border border-slate-800">
            <p className="text-xs text-slate-400 font-medium">FDR &lt; 0.1 Discoveries</p>
            <p className="text-2xl font-extrabold text-cyan-400 mt-0.5">{stats.fdr01}</p>
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
              aria-label="Search metabolites"
              type="text"
              placeholder="Search by metabolite name, HMDB, KEGG, SMILES..."
              value={searchQuery}
              onChange={(e) => handleSearchChange(e.target.value)}
              className="w-full bg-slate-900/90 border border-slate-800 focus:border-cyan-500/60 text-slate-200 text-xs rounded-xl pl-10 pr-4 py-2.5 outline-none transition"
            />
          </div>

          {/* Super Pathway Filter */}
          <div>
            <select
              aria-label="Filter by super pathway"
              value={selectedSuperPathway}
              onChange={(e) => { setSelectedSuperPathway(e.target.value); setCurrentPage(1); }}
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
              aria-label="Filter by significance"
              value={selectedSigTier}
              onChange={(e) => { setSelectedSigTier(e.target.value); setCurrentPage(1); }}
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
              aria-label="Filter by direction"
              value={selectedDirection}
              onChange={(e) => { setSelectedDirection(e.target.value); setCurrentPage(1); }}
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
            {hasV12Subset && (
            <label className="flex items-center gap-2 cursor-pointer text-slate-300 hover:text-white">
              <input
                type="checkbox"
                checked={v12PanelOnly}
                onChange={(e) => { setV12PanelOnly(e.target.checked); setCurrentPage(1); }}
                className="rounded bg-slate-900 border-slate-700 text-cyan-500 focus:ring-0"
              />
              <span className="font-medium">Show v12 Biomarker Panel Only</span>
            </label>
            )}
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
      <div className="flex flex-wrap items-center gap-2 border-b border-slate-800 pb-2" role="tablist" aria-label="Explorer views">
        <button
          role="tab"
          aria-selected={activeTab === "matrix"}
          aria-controls="matrix-panel"
          tabIndex={activeTab === "matrix" ? 0 : -1}
          onKeyDown={handleTabKeyDown}
          onClick={() => setActiveTab("matrix")}
          className={`px-4 py-2.5 rounded-xl font-bold text-xs flex items-center gap-2 transition cursor-pointer ${
            activeTab === "matrix"
              ? "bg-cyan-500 text-slate-950 shadow-lg shadow-cyan-500/20"
              : "bg-slate-900/80 text-slate-400 hover:text-white hover:bg-slate-800"
          }`}
        >
          <Layers className="w-4 h-4" /> Cross-Comparison Matrix ({Object.keys(COMPARISON_LABELS).length} Comparisons)
        </button>

        <button
          role="tab"
          aria-selected={activeTab === "volcano"}
          aria-controls="volcano-panel"
          tabIndex={activeTab === "volcano" ? 0 : -1}
          onKeyDown={handleTabKeyDown}
          onClick={() => setActiveTab("volcano")}
          className={`px-4 py-2.5 rounded-xl font-bold text-xs flex items-center gap-2 transition cursor-pointer ${
            activeTab === "volcano"
              ? "bg-cyan-500 text-slate-950 shadow-lg shadow-cyan-500/20"
              : "bg-slate-900/80 text-slate-400 hover:text-white hover:bg-slate-800"
          }`}
        >
          <Activity className="w-4 h-4" /> Volcano Plot Explorer
        </button>

        <button
          role="tab"
          aria-selected={activeTab === "literature"}
          aria-controls="literature-panel"
          tabIndex={activeTab === "literature" ? 0 : -1}
          onKeyDown={handleTabKeyDown}
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
        <section id="matrix-panel" role="tabpanel" className="glass-panel min-w-0 rounded-2xl p-4 border border-slate-800 space-y-4">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2">
            <p className="text-xs text-slate-400">
              Displaying <strong className="text-white">{sortedMetabolites.length}</strong> metabolites across all {Object.keys(COMPARISON_LABELS).length} comparisons. Click any column header to sort. Click any row for full annotation.
            </p>
            {/* Pagination Info */}
            <p className="text-xs text-slate-500">
              Page <strong className="text-slate-300">{currentPage}</strong> of <strong className="text-slate-300">{totalPages}</strong> ({ROWS_PER_PAGE} per page)
            </p>
          </div>

          <div className="w-full max-w-full min-w-0 overflow-x-auto rounded-xl border border-slate-800">
            <table className="w-full min-w-[1060px] text-xs text-left">
              <thead className="bg-slate-900 text-slate-300 font-bold uppercase border-b border-slate-800 select-none">
                <tr>
                  <th
                    aria-sort={sortColumn === "name" ? (sortDirection === "asc" ? "ascending" : "descending") : "none"}
                    className="py-3 px-4"
                  >
                    <button type="button" onClick={() => handleSort("name")} className="flex items-center gap-1 cursor-pointer hover:text-cyan-400 transition">
                      Metabolite Name {sortIcon("name")}
                    </button>
                  </th>
                  <th
                    aria-sort={sortColumn === "pathway" ? (sortDirection === "asc" ? "ascending" : "descending") : "none"}
                    className="py-3 px-3"
                  >
                    <button type="button" onClick={() => handleSort("pathway")} className="flex items-center gap-1 cursor-pointer hover:text-cyan-400 transition">
                      Super Pathway {sortIcon("pathway")}
                    </button>
                  </th>
                  {Object.entries(COMPARISON_LABELS).map(([key]) => {
                    const headerInfo = MATRIX_HEADERS[key as ComparisonKey] || { title: key, subtitle: "" };
                    return (
                      <th
                        key={key}
                        aria-sort={sortColumn === key ? (sortDirection === "asc" ? "ascending" : "descending") : "none"}
                        className="py-3 px-3 text-center min-w-[120px]"
                      >
                        <button type="button" onClick={() => handleSort(key)} className="flex w-full flex-col items-center cursor-pointer hover:text-cyan-400 transition">
                          <span className="flex items-center gap-1">{headerInfo.title} {sortIcon(key)}</span>
                          <span className="text-[9px] text-slate-500 font-normal">
                            {headerInfo.subtitle}
                          </span>
                        </button>
                      </th>
                    );
                  })}
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 font-mono">
                {paginatedMetabolites.map((m) => (
                  <tr
                    key={m.chem_id}
                    onClick={() => setInspectedMetabolite(m)}
                    onKeyDown={(event) => {
                      if (event.key === "Enter" || event.key === " ") {
                        event.preventDefault();
                        setInspectedMetabolite(m);
                      }
                    }}
                    tabIndex={0}
                    aria-label={`View details for ${m.chemical_name}`}
                    className="hover:bg-slate-900/70 focus-visible:outline-2 focus-visible:outline-cyan-400 focus-visible:outline-offset-[-2px] cursor-pointer transition group"
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

                    {/* Comparative Columns */}
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

          {sortedMetabolites.length === 0 && (
            <div className="rounded-xl border border-dashed border-slate-700 p-8 text-center text-sm text-slate-400">
              No metabolites match the current filters. Try resetting or broadening the selection.
            </div>
          )}

          {/* Pagination Controls */}
          {totalPages > 1 && (
            <div className="flex items-center justify-between pt-2">
              <button
                onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                disabled={currentPage === 1}
                className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-slate-900/80 text-slate-300 border border-slate-800 hover:bg-slate-800 disabled:opacity-30 disabled:cursor-not-allowed transition flex items-center gap-1 cursor-pointer"
              >
                <ChevronLeft className="w-3.5 h-3.5" /> Previous
              </button>
              <div className="flex items-center gap-1">
                {Array.from({ length: Math.min(totalPages, 7) }, (_, i) => {
                  let pageNum: number;
                  if (totalPages <= 7) {
                    pageNum = i + 1;
                  } else if (currentPage <= 4) {
                    pageNum = i + 1;
                  } else if (currentPage >= totalPages - 3) {
                    pageNum = totalPages - 6 + i;
                  } else {
                    pageNum = currentPage - 3 + i;
                  }
                  return (
                    <button
                      key={pageNum}
                      onClick={() => setCurrentPage(pageNum)}
                      aria-current={currentPage === pageNum ? "page" : undefined}
                      aria-label={`Page ${pageNum}`}
                      className={`w-8 h-8 rounded-lg text-xs font-bold transition cursor-pointer ${
                        currentPage === pageNum
                          ? "bg-cyan-500 text-slate-950 shadow-lg shadow-cyan-500/20"
                          : "bg-slate-900/80 text-slate-400 hover:text-white border border-slate-800"
                      }`}
                    >
                      {pageNum}
                    </button>
                  );
                })}
              </div>
              <button
                onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                disabled={currentPage === totalPages}
                className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-slate-900/80 text-slate-300 border border-slate-800 hover:bg-slate-800 disabled:opacity-30 disabled:cursor-not-allowed transition flex items-center gap-1 cursor-pointer"
              >
                Next <ChevronRight className="w-3.5 h-3.5" />
              </button>
            </div>
          )}
        </section>
      )}

      {/* TAB 2: Single Comparison Volcano Plot */}
      {activeTab === "volcano" && (
        <div id="volcano-panel" role="tabpanel" className="min-w-0 space-y-6">
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
        <div id="literature-panel" role="tabpanel">
          <LiteratureHub
            metabolites={filteredMetabolites}
            onSelectMetabolite={(m) => setInspectedMetabolite(m)}
          />
        </div>
      )}

      {/* Metabolite Detail Modal */}
      <MetaboliteModal
        metabolite={inspectedMetabolite}
        onClose={closeModal}
      />

      {/* Footer with data version */}
      <footer className="text-center text-xs text-slate-600 pb-4 border-t border-slate-800/40 pt-4">
        Data version: {release.version} · {metabolites.length} metabolites · {Object.keys(COMPARISON_LABELS).length} comparisons · Released {release.released_on}
      </footer>
    </main>
  );
}
