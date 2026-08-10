"use client";

import { useMemo } from "react";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { ComparisonKey, COMPARISON_LABELS, Metabolite } from "@/types/metabolite";

interface InsightsDashboardProps {
  metabolites: Metabolite[];
  activeComparison: ComparisonKey;
  onComparisonChange: (comparison: ComparisonKey) => void;
}

const COMPACT_LABELS: Record<ComparisonKey, string> = {
  Depressive_vs_Control: "MDD",
  Cognitive_vs_Control: "Cognitive",
  MildPTSD_vs_Control: "Mild PTSD",
  SeverePTSD_vs_Control: "Severe PTSD",
  MildPTSD_vs_SeverePTSD: "Mild vs Severe",
  CogPos_vs_CogNeg: "Cog+ vs Cog−",
};

const CHART_COLORS = {
  cobalt: "#3157d5",
  teal: "#0f8b8d",
  coral: "#e2674a",
  gold: "#d99b2b",
  violet: "#7759b7",
  quiet: "#cbd5e1",
};

const tooltipStyle = {
  background: "#ffffff",
  border: "1px solid #dbe3ee",
  borderRadius: 12,
  boxShadow: "0 12px 30px rgba(31, 44, 69, 0.12)",
  color: "#172033",
  fontSize: 12,
};

function pearsonCorrelation(xValues: number[], yValues: number[]) {
  if (xValues.length < 2 || xValues.length !== yValues.length) return 0;
  const xMean = xValues.reduce((sum, value) => sum + value, 0) / xValues.length;
  const yMean = yValues.reduce((sum, value) => sum + value, 0) / yValues.length;
  let numerator = 0;
  let xVariance = 0;
  let yVariance = 0;
  xValues.forEach((value, index) => {
    const xDelta = value - xMean;
    const yDelta = yValues[index] - yMean;
    numerator += xDelta * yDelta;
    xVariance += xDelta * xDelta;
    yVariance += yDelta * yDelta;
  });
  const denominator = Math.sqrt(xVariance * yVariance);
  return denominator === 0 ? 0 : numerator / denominator;
}

function correlationColor(value: number) {
  const strength = 0.12 + Math.abs(value) * 0.78;
  return value >= 0
    ? `rgba(226, 103, 74, ${strength})`
    : `rgba(49, 87, 213, ${strength})`;
}

export default function InsightsDashboard({
  metabolites,
  activeComparison,
  onComparisonChange,
}: InsightsDashboardProps) {
  const comparisonData = useMemo(
    () => (Object.keys(COMPARISON_LABELS) as ComparisonKey[]).map((key) => {
      const comparisons = metabolites.map((metabolite) => metabolite.comparisons[key]).filter(Boolean);
      return {
        comparison: COMPACT_LABELS[key],
        "P < 0.05": comparisons.filter((item) => item && item["P.Value"] < 0.05).length,
        "P < 0.01": comparisons.filter((item) => item && item["P.Value"] < 0.01).length,
        "FDR < 0.1": comparisons.filter((item) => item && item["adj.P.Val"] < 0.1).length,
      };
    }),
    [metabolites],
  );

  const pathwayData = useMemo(() => {
    const counts = new Map<string, number>();
    metabolites.forEach((metabolite) => {
      counts.set(metabolite.super_pathway, (counts.get(metabolite.super_pathway) ?? 0) + 1);
    });
    return Array.from(counts, ([pathway, count]) => ({ pathway, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 8)
      .reverse();
  }, [metabolites]);

  const directionData = useMemo(() => {
    const counts = { UP: 0, DOWN: 0, NC: 0 };
    metabolites.forEach((metabolite) => {
      const comparison = metabolite.comparisons[activeComparison];
      if (comparison) counts[comparison.direction] += 1;
    });
    return [
      { name: "Upregulated", value: counts.UP, color: CHART_COLORS.coral },
      { name: "Downregulated", value: counts.DOWN, color: CHART_COLORS.cobalt },
      { name: "Not significant", value: counts.NC, color: CHART_COLORS.quiet },
    ];
  }, [activeComparison, metabolites]);

  const effectDistribution = useMemo(() => {
    const values = metabolites
      .map((metabolite) => metabolite.comparisons[activeComparison]?.logFC)
      .filter((value): value is number => typeof value === "number" && Number.isFinite(value));
    if (values.length === 0) return [];
    const minimum = Math.min(...values);
    const maximum = Math.max(...values);
    const binCount = 12;
    const width = maximum === minimum ? 1 : (maximum - minimum) / binCount;
    const bins = Array.from({ length: binCount }, (_, index) => ({
      effect: minimum + width * (index + 0.5),
      count: 0,
    }));
    values.forEach((value) => {
      const index = Math.min(binCount - 1, Math.max(0, Math.floor((value - minimum) / width)));
      bins[index].count += 1;
    });
    return bins.map((bin) => ({ ...bin, effectLabel: bin.effect.toFixed(2) }));
  }, [activeComparison, metabolites]);

  const vennData = useMemo(() => {
    const keys: ComparisonKey[] = [
      "Depressive_vs_Control",
      "Cognitive_vs_Control",
      "SeverePTSD_vs_Control",
    ];
    const [setA, setB, setC] = keys.map((key) => new Set(
      metabolites
        .filter((metabolite) => (metabolite.comparisons[key]?.["P.Value"] ?? 1) < 0.05)
        .map((metabolite) => metabolite.chem_id),
    ));
    const allIds = new Set([...setA, ...setB, ...setC]);
    const counts = { onlyA: 0, onlyB: 0, onlyC: 0, ab: 0, ac: 0, bc: 0, abc: 0 };
    allIds.forEach((id) => {
      const inA = setA.has(id);
      const inB = setB.has(id);
      const inC = setC.has(id);
      if (inA && inB && inC) counts.abc += 1;
      else if (inA && inB) counts.ab += 1;
      else if (inA && inC) counts.ac += 1;
      else if (inB && inC) counts.bc += 1;
      else if (inA) counts.onlyA += 1;
      else if (inB) counts.onlyB += 1;
      else if (inC) counts.onlyC += 1;
    });
    return { counts, totals: [setA.size, setB.size, setC.size] };
  }, [metabolites]);

  const correlationMatrix = useMemo(() => {
    const keys = Object.keys(COMPARISON_LABELS) as ComparisonKey[];
    return keys.map((rowKey) => keys.map((columnKey) => {
      const xValues: number[] = [];
      const yValues: number[] = [];
      metabolites.forEach((metabolite) => {
        const x = metabolite.comparisons[rowKey]?.logFC;
        const y = metabolite.comparisons[columnKey]?.logFC;
        if (typeof x === "number" && typeof y === "number") {
          xValues.push(x);
          yValues.push(y);
        }
      });
      return rowKey === columnKey ? 1 : pearsonCorrelation(xValues, yValues);
    }));
  }, [metabolites]);

  const comparisonKeys = Object.keys(COMPARISON_LABELS) as ComparisonKey[];

  return (
    <section id="insights-panel" role="tabpanel" className="space-y-5">
      <div className="insights-intro rounded-[28px] p-5 sm:p-7">
        <div className="max-w-3xl">
          <p className="text-xs font-bold uppercase tracking-[0.18em] text-indigo-700">Analytical overview</p>
          <h2 className="mt-2 text-2xl sm:text-3xl font-extrabold tracking-tight text-slate-950">
            Patterns across the complete metabolite landscape
          </h2>
          <p className="mt-2 text-sm leading-6 text-slate-600">
            These views summarize the current filtered selection. Use them to compare discovery yield, pathway coverage,
            directionality, and effect-size shape before inspecting individual metabolites.
          </p>
        </div>
      </div>

      <article className="insight-card insight-card-feature rounded-[24px] p-4 sm:p-6">
        <div className="mb-5 flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="chart-eyebrow">Discovery yield</p>
            <h3 className="text-lg font-bold text-slate-950">Significant metabolites by comparison</h3>
          </div>
          <p className="text-xs text-slate-500">Nominal and multiple-testing thresholds shown together</p>
        </div>
        <div className="h-[330px] w-full" role="img" aria-label="Grouped bar chart of significant metabolite counts by comparison">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={comparisonData} margin={{ top: 6, right: 8, bottom: 36, left: -12 }}>
              <CartesianGrid vertical={false} stroke="#dfe5ee" strokeDasharray="2 5" />
              <XAxis dataKey="comparison" tick={{ fill: "#526078", fontSize: 11 }} axisLine={false} tickLine={false} angle={-18} textAnchor="end" height={62} />
              <YAxis allowDecimals={false} tick={{ fill: "#65728a", fontSize: 11 }} axisLine={false} tickLine={false} />
              <Tooltip contentStyle={tooltipStyle} cursor={{ fill: "rgba(49, 87, 213, 0.06)" }} />
              <Legend wrapperStyle={{ fontSize: 12, paddingTop: 8 }} />
              <Bar dataKey="P < 0.05" fill={CHART_COLORS.gold} radius={[5, 5, 0, 0]} />
              <Bar dataKey="P < 0.01" fill={CHART_COLORS.teal} radius={[5, 5, 0, 0]} />
              <Bar dataKey="FDR < 0.1" fill={CHART_COLORS.cobalt} radius={[5, 5, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </article>

      <div className="grid grid-cols-1 gap-5 lg:grid-cols-5">
        <article className="insight-card venn-card rounded-[24px] p-4 sm:p-6 lg:col-span-2">
          <p className="chart-eyebrow">Shared discoveries</p>
          <h3 className="text-lg font-bold text-slate-950">Three-phenotype Venn diagram</h3>
          <p className="mt-1 text-xs leading-5 text-slate-500">Exclusive overlap of nominal hits at P &lt; 0.05.</p>
          <svg
            className="mt-3 h-auto w-full"
            viewBox="0 0 520 390"
            role="img"
            aria-labelledby="venn-title venn-description"
          >
            <title id="venn-title">Venn diagram of significant metabolites</title>
            <desc id="venn-description">Overlap among MDD, Cognitive, and Severe PTSD comparisons.</desc>
            <circle cx="200" cy="155" r="112" fill="#e2674a" fillOpacity="0.23" stroke="#c9543c" strokeWidth="2" />
            <circle cx="320" cy="155" r="112" fill="#3157d5" fillOpacity="0.2" stroke="#3157d5" strokeWidth="2" />
            <circle cx="260" cy="247" r="112" fill="#0f8b8d" fillOpacity="0.22" stroke="#0f8b8d" strokeWidth="2" />
            <text x="105" y="42" className="venn-label" textAnchor="middle">MDD · {vennData.totals[0]}</text>
            <text x="415" y="42" className="venn-label" textAnchor="middle">Cognitive · {vennData.totals[1]}</text>
            <text x="260" y="384" className="venn-label" textAnchor="middle">Severe PTSD · {vennData.totals[2]}</text>
            <text x="145" y="155" className="venn-count" textAnchor="middle">{vennData.counts.onlyA}</text>
            <text x="375" y="155" className="venn-count" textAnchor="middle">{vennData.counts.onlyB}</text>
            <text x="260" y="315" className="venn-count" textAnchor="middle">{vennData.counts.onlyC}</text>
            <text x="260" y="120" className="venn-count" textAnchor="middle">{vennData.counts.ab}</text>
            <text x="198" y="235" className="venn-count" textAnchor="middle">{vennData.counts.ac}</text>
            <text x="322" y="235" className="venn-count" textAnchor="middle">{vennData.counts.bc}</text>
            <text x="260" y="193" className="venn-count venn-count-core" textAnchor="middle">{vennData.counts.abc}</text>
          </svg>
        </article>

        <article className="insight-card heatmap-card rounded-[24px] p-4 sm:p-6 lg:col-span-3">
          <p className="chart-eyebrow">Concordance</p>
          <h3 className="text-lg font-bold text-slate-950">Comparison correlation heatmap</h3>
          <p className="mt-1 text-xs leading-5 text-slate-500">Pearson correlation of metabolite logFC values using pairwise-complete observations.</p>
          <div className="mt-5 w-full overflow-x-auto pb-2">
            <table className="correlation-table min-w-[620px] border-separate border-spacing-1" aria-label="Log fold-change correlation matrix">
              <thead>
                <tr>
                  <th scope="col" className="w-28" aria-label="Comparison" />
                  {comparisonKeys.map((key) => (
                    <th key={key} scope="col" className="heatmap-axis px-1 pb-2 text-center">{COMPACT_LABELS[key]}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {comparisonKeys.map((rowKey, rowIndex) => (
                  <tr key={rowKey}>
                    <th scope="row" className="heatmap-axis pr-2 text-right">{COMPACT_LABELS[rowKey]}</th>
                    {comparisonKeys.map((columnKey, columnIndex) => {
                      const value = correlationMatrix[rowIndex][columnIndex];
                      return (
                        <td
                          key={columnKey}
                          className="heatmap-cell h-14 min-w-16 rounded-lg text-center font-mono text-xs font-bold"
                          style={{ backgroundColor: correlationColor(value), color: Math.abs(value) > 0.52 ? "#ffffff" : "#27364d" }}
                          title={`${COMPARISON_LABELS[rowKey]} vs ${COMPARISON_LABELS[columnKey]}: r = ${value.toFixed(3)}`}
                        >
                          {value.toFixed(2)}
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-3 flex items-center justify-end gap-2 text-[11px] font-semibold text-slate-500">
            <span>−1</span><span className="heatmap-legend" aria-hidden="true" /><span>+1</span>
          </div>
        </article>
      </div>

      <div className="grid grid-cols-1 gap-5 lg:grid-cols-5">
        <article className="insight-card rounded-[24px] p-4 sm:p-6 lg:col-span-3">
          <p className="chart-eyebrow">Coverage</p>
          <h3 className="text-lg font-bold text-slate-950">Leading super pathways</h3>
          <div className="mt-4 h-[340px] w-full" role="img" aria-label="Horizontal bar chart of metabolite counts by super pathway">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={pathwayData} layout="vertical" margin={{ top: 4, right: 16, bottom: 4, left: 12 }}>
                <CartesianGrid horizontal={false} stroke="#e6ebf2" strokeDasharray="2 5" />
                <XAxis type="number" allowDecimals={false} tick={{ fill: "#65728a", fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis type="category" dataKey="pathway" width={142} tick={{ fill: "#344258", fontSize: 11 }} axisLine={false} tickLine={false} />
                <Tooltip contentStyle={tooltipStyle} cursor={{ fill: "rgba(15, 139, 141, 0.06)" }} />
                <Bar dataKey="count" fill={CHART_COLORS.teal} radius={[0, 8, 8, 0]} barSize={18} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </article>

        <article className="insight-card insight-card-tint rounded-[24px] p-4 sm:p-6 lg:col-span-2">
          <label htmlFor="direction-comparison" className="chart-eyebrow block">Direction profile</label>
          <select
            id="direction-comparison"
            value={activeComparison}
            onChange={(event) => onComparisonChange(event.target.value as ComparisonKey)}
            className="mt-2 w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm font-semibold text-slate-800 outline-none focus:border-indigo-500"
          >
            {(Object.keys(COMPARISON_LABELS) as ComparisonKey[]).map((key) => (
              <option key={key} value={key}>{COMPARISON_LABELS[key]}</option>
            ))}
          </select>
          <div className="mt-2 h-[300px] w-full" role="img" aria-label={`Donut chart of effect directions for ${COMPARISON_LABELS[activeComparison]}`}>
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie data={directionData} dataKey="value" nameKey="name" innerRadius={62} outerRadius={92} paddingAngle={2} stroke="none">
                  {directionData.map((entry) => <Cell key={entry.name} fill={entry.color} />)}
                </Pie>
                <Tooltip contentStyle={tooltipStyle} />
                <Legend verticalAlign="bottom" wrapperStyle={{ fontSize: 12 }} />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </article>
      </div>

      <article className="insight-card insight-card-quiet rounded-[24px] p-4 sm:p-6">
        <div className="mb-4">
          <p className="chart-eyebrow">Distribution</p>
          <h3 className="text-lg font-bold text-slate-950">Effect-size density · {COMPARISON_LABELS[activeComparison]}</h3>
        </div>
        <div className="h-[270px] w-full" role="img" aria-label={`Area chart of log fold-change distribution for ${COMPARISON_LABELS[activeComparison]}`}>
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={effectDistribution} margin={{ top: 8, right: 10, bottom: 12, left: -12 }}>
              <defs>
                <linearGradient id="effectFill" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={CHART_COLORS.violet} stopOpacity={0.42} />
                  <stop offset="100%" stopColor={CHART_COLORS.violet} stopOpacity={0.03} />
                </linearGradient>
              </defs>
              <CartesianGrid vertical={false} stroke="#dfe5ee" strokeDasharray="2 5" />
              <XAxis dataKey="effectLabel" tick={{ fill: "#65728a", fontSize: 10 }} axisLine={false} tickLine={false} interval={1} />
              <YAxis allowDecimals={false} tick={{ fill: "#65728a", fontSize: 11 }} axisLine={false} tickLine={false} />
              <Tooltip contentStyle={tooltipStyle} labelFormatter={(label) => `logFC ${label}`} />
              <Area type="monotone" dataKey="count" stroke={CHART_COLORS.violet} strokeWidth={3} fill="url(#effectFill)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </article>
    </section>
  );
}
