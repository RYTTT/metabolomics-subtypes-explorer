"use client";

import React from "react";
import {
  ScatterChart,
  Scatter,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  ReferenceLine,
  Cell,
} from "recharts";
import { Metabolite, ComparisonKey, COMPARISON_LABELS } from "@/types/metabolite";

interface VolcanoPlotProps {
  metabolites: Metabolite[];
  activeComparison: ComparisonKey;
  onSelectMetabolite: (metabolite: Metabolite) => void;
}

export default function VolcanoPlot({
  metabolites,
  activeComparison,
  onSelectMetabolite,
}: VolcanoPlotProps) {
  const data = metabolites
    .map((m) => {
      const comp = m.comparisons[activeComparison];
      if (!comp) return null;
      const logFC = comp.logFC;
      const pVal = comp["P.Value"];
      const negLogP = pVal > 0 ? -Math.log10(pVal) : 0;
      return {
        id: m.chem_id,
        name: m.chemical_name,
        logFC: Number(logFC.toFixed(4)),
        negLogP: Number(negLogP.toFixed(3)),
        pVal: comp["P.Value"],
        adjP: comp["adj.P.Val"],
        color: comp.color,
        direction: comp.direction,
        metabolite: m,
      };
    })
    .filter(Boolean) as Array<{
    id: string;
    name: string;
    logFC: number;
    negLogP: number;
    pVal: number;
    adjP: number;
    color: "red" | "blue" | "grey";
    direction: "UP" | "DOWN" | "NC";
    metabolite: Metabolite;
  }>;

  const getColor = (color: string) => {
    if (color === "red") return "#ef4444"; // Red for up
    if (color === "blue") return "#3b82f6"; // Blue for down
    return "#64748b"; // Slate for non-sig
  };

  return (
    <div className="w-full glass-panel rounded-2xl p-6 shadow-xl border border-slate-800">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-4">
        <div>
          <h3 className="text-xl font-bold text-white flex items-center gap-2">
            <span className="w-3 h-3 rounded-full bg-cyan-400 animate-pulse"></span>
            Volcano Plot — {COMPARISON_LABELS[activeComparison]}
          </h3>
          <p className="text-xs text-slate-400 mt-1">
            <span className="text-red-400 font-semibold">Red</span> = Upregulated (logFC &gt; 0, P &lt; 0.05) |{" "}
            <span className="text-blue-400 font-semibold">Blue</span> = Downregulated (logFC &lt; 0, P &lt; 0.05) |{" "}
            Dashed lines: P = 0.05 (-log10 = 1.3) and P = 0.01 (-log10 = 2.0).
          </p>
        </div>
      </div>

      <div
        className="h-[360px] sm:h-[420px] w-full min-w-0"
        role="img"
        aria-label={`Volcano plot for ${COMPARISON_LABELS[activeComparison]}`}
      >
        <ResponsiveContainer width="100%" height="100%">
          <ScatterChart margin={{ top: 20, right: 30, bottom: 20, left: 10 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
            <XAxis
              type="number"
              dataKey="logFC"
              name="log2 Fold Change"
              stroke="#94a3b8"
              fontSize={12}
              tickFormatter={(v) => v.toFixed(1)}
              label={{ value: "log2 Fold Change (logFC)", position: "bottom", fill: "#94a3b8", offset: 0 }}
            />
            <YAxis
              type="number"
              dataKey="negLogP"
              name="-log10(P-value)"
              stroke="#94a3b8"
              fontSize={12}
              label={{ value: "-log10(P-value)", angle: -90, position: "insideLeft", fill: "#94a3b8" }}
            />
            {/* P = 0.05 Line */}
            <ReferenceLine y={1.301} stroke="#f59e0b" strokeDasharray="4 4" label={{ value: "P=0.05", fill: "#f59e0b", fontSize: 10 }} />
            {/* P = 0.01 Line */}
            <ReferenceLine y={2.0} stroke="#ef4444" strokeDasharray="4 4" label={{ value: "P=0.01", fill: "#ef4444", fontSize: 10 }} />
            {/* LogFC = 0 center line */}
            <ReferenceLine x={0} stroke="#475569" strokeDasharray="2 2" />

            <Tooltip
              content={({ payload }) => {
                if (payload && payload.length) {
                  const pt = payload[0].payload;
                  return (
                    <div className="glass-panel p-3 rounded-lg shadow-2xl border border-slate-700 text-xs max-w-xs">
                      <p className="font-bold text-white text-sm mb-1">{pt.name}</p>
                      <div className="grid grid-cols-2 gap-x-3 gap-y-1 text-slate-300">
                        <span>logFC:</span> <span className="font-mono text-cyan-300 font-bold">{pt.logFC}</span>
                        <span>P-value:</span> <span className="font-mono text-amber-300">{pt.pVal.toExponential(3)}</span>
                        <span>FDR:</span> <span className="font-mono text-indigo-300">{pt.adjP.toExponential(3)}</span>
                        <span>Direction:</span>{" "}
                        <span
                          className={`font-semibold ${
                            pt.color === "red"
                              ? "text-red-400"
                              : pt.color === "blue"
                              ? "text-blue-400"
                              : "text-slate-400"
                          }`}
                        >
                          {pt.direction}
                        </span>
                      </div>
                      <p className="text-[10px] text-cyan-400 mt-2 italic">Click to view full annotation &amp; literature</p>
                    </div>
                  );
                }
                return null;
              }}
            />

            <Scatter
              data={data}
              onClick={(entry: { metabolite?: Metabolite; payload?: { metabolite?: Metabolite } }) => {
                const met = entry?.metabolite || entry?.payload?.metabolite;
                if (met) {
                  onSelectMetabolite(met);
                }
              }}
              cursor="pointer"
            >
              {data.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={getColor(entry.color)} fillOpacity={entry.color === "grey" ? 0.4 : 0.85} r={entry.color === "grey" ? 4 : 6} />
              ))}
            </Scatter>
          </ScatterChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
