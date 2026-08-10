"use client";

import { useMemo } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Line,
  LineChart,
  Pie,
  PieChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { layout, type ISetOverlap } from "@upsetjs/venn.js";
import { ComparisonKey, COMPARISON_LABELS, Metabolite } from "@/types/metabolite";

interface InsightsDashboardProps {
  metabolites: Metabolite[];
  activeComparison: ComparisonKey;
  onComparisonChange: (comparison: ComparisonKey) => void;
}

const COMPACT_LABELS: Record<ComparisonKey, string> = {
  Depressive_vs_Control: "Depressive",
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

const VENN_SETS = [
  { id: "depressive", label: "Depressive", color: "#d65d47", mask: 1, comparison: "Depressive_vs_Control" },
  { id: "cognitive", label: "Cognitive", color: "#3157d5", mask: 2, comparison: "Cognitive_vs_Control" },
  { id: "mild-ptsd", label: "Mild PTSD", color: "#0f8b8d", mask: 4, comparison: "MildPTSD_vs_Control" },
  { id: "severe-ptsd", label: "Severe PTSD", color: "#d99b2b", mask: 8, comparison: "SeverePTSD_vs_Control" },
] as const;

interface VennArea extends ISetOverlap {
  exact: number;
  label: string;
  mask: number;
}

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
    const series = VENN_SETS.map((set) => ({
      ...set,
      values: metabolites
        .map((metabolite) => metabolite.comparisons[set.comparison]?.logFC)
        .filter((value): value is number => typeof value === "number" && Number.isFinite(value)),
    }));
    const allValues = series.flatMap((set) => set.values);
    if (allValues.length === 0) return [];

    const extent = Math.max(...allValues.map((value) => Math.abs(value))) * 1.08 || 1;
    const pointCount = 61;
    const normalizer = Math.sqrt(2 * Math.PI);
    return Array.from({ length: pointCount }, (_, index) => {
      const effect = -extent + ((extent * 2 * index) / (pointCount - 1));
      const point: Record<string, number> = { effect };
      series.forEach((set) => {
        const mean = set.values.reduce((sum, value) => sum + value, 0) / Math.max(1, set.values.length);
        const variance = set.values.reduce((sum, value) => sum + ((value - mean) ** 2), 0) / Math.max(1, set.values.length - 1);
        const bandwidth = Math.max(0.015, 1.06 * Math.sqrt(variance) * (Math.max(1, set.values.length) ** -0.2));
        point[set.comparison] = set.values.reduce((density, value) => {
          const distance = (effect - value) / bandwidth;
          return density + Math.exp(-0.5 * distance * distance);
        }, 0) / (Math.max(1, set.values.length) * bandwidth * normalizer);
      });
      return point;
    });
  }, [metabolites]);

  const vennData = useMemo(() => {
    const keys: ComparisonKey[] = [
      "Depressive_vs_Control",
      "Cognitive_vs_Control",
      "MildPTSD_vs_Control",
      "SeverePTSD_vs_Control",
    ];
    const sets = keys.map((key) => new Set(
      metabolites
        .filter((metabolite) => (metabolite.comparisons[key]?.["P.Value"] ?? 1) < 0.05)
        .map((metabolite) => metabolite.chem_id),
    ));
    const allIds = new Set(sets.flatMap((set) => Array.from(set)));
    const regions = Array.from({ length: 16 }, () => 0);
    allIds.forEach((id) => {
      const mask = sets.reduce((value, set, index) => value | (set.has(id) ? 1 << index : 0), 0);
      regions[mask] += 1;
    });
    return { regions, totals: sets.map((set) => set.size) };
  }, [metabolites]);

  const vennLayout = useMemo(() => {
    const areas: VennArea[] = Array.from({ length: 15 }, (_, index) => {
      const mask = index + 1;
      const members = VENN_SETS.filter((set) => (mask & set.mask) !== 0);
      const inclusiveSize = vennData.regions.reduce(
        (sum, count, regionMask) => ((regionMask & mask) === mask ? sum + count : sum),
        0,
      );
      return {
        sets: members.map((set) => set.id),
        size: inclusiveSize,
        exact: vennData.regions[mask],
        label: members.map((set) => set.label).join(" + "),
        mask,
      };
    });

    // Pairwise zeroes remain as layout constraints. Empty higher-order regions are
    // omitted so the package produces an Euler-style geometry matching this dataset.
    const layoutAreas = areas.filter((area) => area.sets.length <= 2 || area.size > 0);
    return layout(layoutAreas, {
      width: 640,
      height: 400,
      padding: 24,
      distinct: true,
      round: 2,
    });
  }, [vennData]);

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

      <div className="space-y-5">
        <article className="insight-card venn-card rounded-[24px] p-4 sm:p-6">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <p className="chart-eyebrow">Shared discoveries</p>
              <h3 className="text-lg font-bold text-slate-950">Four-subtype Venn diagram</h3>
              <p className="mt-1 max-w-2xl text-xs leading-5 text-slate-500">
                Nominally significant metabolites across four subtype-vs-control comparisons.
              </p>
            </div>
            <span className="venn-threshold">Significance threshold&nbsp; P &lt; 0.05</span>
          </div>

          <div className="venn-layout mt-5">
            <div>
              <ul className="venn-legend" aria-label="Subtype set totals">
                {VENN_SETS.map((set, index) => (
                  <li key={set.id}><i style={{ backgroundColor: set.color }} /><span>{set.label}</span><b>{vennData.totals[index]}</b></li>
                ))}
              </ul>

              <div className="venn-stage mt-3">
                <svg
                  className="h-auto w-full"
                  viewBox="0 0 640 400"
                  role="img"
                  aria-labelledby="venn-title venn-description"
                >
                  <title id="venn-title">Area-proportional four-subtype Venn and Euler diagram</title>
                  <desc id="venn-description">The diagram is calculated by Venn.js from the observed subtype set sizes and intersections. Set area and overlap are optimized to match the data.</desc>
                  {vennLayout.filter((area) => area.data.sets.length === 1).map((area) => {
                    const set = VENN_SETS.find((candidate) => candidate.id === area.data.sets[0]);
                    return (
                      <path
                        key={area.data.sets.join("-")}
                        d={area.path}
                        className="venn-engine-set"
                        style={{ fill: set?.color, stroke: set?.color }}
                      >
                        <title>{area.data.label}: {area.data.size} total metabolites</title>
                      </path>
                    );
                  })}
                  {vennLayout.filter((area) => area.data.sets.length > 1 && area.data.exact > 0).map((area) => (
                    <path
                      key={`region-${area.data.mask}`}
                      d={area.distinctPath}
                      className={`venn-engine-region venn-engine-region-${area.data.sets.length}`}
                    >
                      <title>{area.data.label}: {area.data.exact} exclusive metabolites</title>
                    </path>
                  ))}
                  {vennLayout.filter((area) => area.data.sets.length === 1).map((area) => (
                    <g key={`label-${area.data.mask}`} transform={`translate(${area.text.x} ${area.text.y})`} className="venn-engine-set-label">
                      <text y="-7" textAnchor="middle">{area.data.label}</text>
                      <text y="19" textAnchor="middle" className="venn-engine-unique-count">{area.data.exact}</text>
                      <text y="34" textAnchor="middle" className="venn-engine-unique-caption">unique</text>
                    </g>
                  ))}
                  {vennLayout.filter((area) => area.data.sets.length > 1 && area.data.exact > 0).map((area) => (
                    <g key={`count-${area.data.mask}`} transform={`translate(${area.text.x} ${area.text.y})`} className="venn-engine-overlap-count">
                      <circle r="13" />
                      <text y="4" textAnchor="middle">{area.data.exact}</text>
                      <title>{area.data.label}: {area.data.exact} exclusive metabolites</title>
                    </g>
                  ))}
                </svg>
                <p className="venn-figure-note">Area-proportional layout calculated from observed set and intersection sizes.</p>
              </div>
            </div>

            <aside className="venn-intersections" aria-label="Exact exclusive Venn region counts">
              <div>
                <p className="chart-eyebrow">Exact intersections</p>
                <h4 className="mt-1 font-bold text-slate-900">Shared membership</h4>
                <p className="mt-1 text-xs leading-5 text-slate-500">Each value excludes metabolites found in any additional subtype.</p>
                <p className="venn-all-four mt-3"><span>All four subtypes</span><b>{vennData.regions[15]}</b></p>
              </div>
              <div className="venn-region-grid mt-5 space-y-5">
                <div>
                  <p className="venn-region-heading">Two subtypes only</p>
                  <div className="mt-2 grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2">
                    <span>Depressive + Cognitive <b>{vennData.regions[3]}</b></span><span>Depressive + Mild PTSD <b>{vennData.regions[5]}</b></span>
                    <span>Depressive + Severe PTSD <b>{vennData.regions[9]}</b></span><span>Cognitive + Mild PTSD <b>{vennData.regions[6]}</b></span>
                    <span>Cognitive + Severe PTSD <b>{vennData.regions[10]}</b></span><span>Mild + Severe PTSD <b>{vennData.regions[12]}</b></span>
                  </div>
                </div>
                <div>
                  <p className="venn-region-heading">Three subtypes only</p>
                  <div className="mt-2 grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2">
                    <span>Dep + Cog + Mild <b>{vennData.regions[7]}</b></span><span>Dep + Cog + Severe <b>{vennData.regions[11]}</b></span>
                    <span>Dep + Mild + Severe <b>{vennData.regions[13]}</b></span><span>Cog + Mild + Severe <b>{vennData.regions[14]}</b></span>
                  </div>
                </div>
              </div>
            </aside>
          </div>
        </article>

        <article className="insight-card heatmap-card rounded-[24px] p-4 sm:p-6">
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
          <div className="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
            <p className="chart-eyebrow">Distribution</p>
            <p className="text-xs font-semibold text-slate-500">Active comparison is emphasized</p>
          </div>
          <h3 className="mt-2 text-lg font-bold text-slate-950">Effect-size density across four subtypes</h3>
          <p className="mt-1 text-xs leading-5 text-slate-500">Gaussian kernel density of metabolite log fold changes for each subtype-versus-control comparison.</p>
        </div>
        <div className="h-[310px] w-full" role="img" aria-label="Density line chart comparing log fold-change distributions for Depressive, Cognitive, Mild PTSD, and Severe PTSD subtypes versus control">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={effectDistribution} margin={{ top: 8, right: 18, bottom: 12, left: -4 }}>
              <CartesianGrid vertical={false} stroke="#dfe5ee" strokeDasharray="2 5" />
              <XAxis
                type="number"
                dataKey="effect"
                domain={["dataMin", "dataMax"]}
                tick={{ fill: "#65728a", fontSize: 10 }}
                tickFormatter={(value) => Number(value).toFixed(2)}
                axisLine={false}
                tickLine={false}
              />
              <YAxis tick={{ fill: "#65728a", fontSize: 11 }} tickFormatter={(value) => Number(value).toFixed(1)} axisLine={false} tickLine={false} width={42} />
              <ReferenceLine x={0} stroke="#94a3b8" strokeDasharray="4 4" />
              <Tooltip
                contentStyle={tooltipStyle}
                labelFormatter={(label) => `logFC ${Number(label).toFixed(3)}`}
                formatter={(value, name) => [Number(value).toFixed(3), name]}
              />
              <Legend verticalAlign="top" align="right" wrapperStyle={{ fontSize: 12, paddingBottom: 12 }} />
              {VENN_SETS.map((set) => {
                const hasActiveSubtype = VENN_SETS.some((candidate) => candidate.comparison === activeComparison);
                const isActive = set.comparison === activeComparison;
                return (
                  <Line
                    key={set.comparison}
                    type="monotone"
                    dataKey={set.comparison}
                    name={set.label}
                    stroke={set.color}
                    strokeWidth={isActive ? 4 : 2.4}
                    strokeOpacity={hasActiveSubtype && !isActive ? 0.48 : 0.9}
                    dot={false}
                    activeDot={{ r: 4 }}
                  />
                );
              })}
            </LineChart>
          </ResponsiveContainer>
        </div>
      </article>
    </section>
  );
}
