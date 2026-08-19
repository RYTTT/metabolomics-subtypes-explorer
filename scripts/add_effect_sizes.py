#!/usr/bin/env python3
"""Add or verify Cohen's d and Hedges' g in differential-analysis CSV outputs."""

import argparse
import csv
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

FILE_SAMPLE_SIZES = {
    # Original-release analyses retained for reproducibility.
    "result/Subtypes_Depressive_vs_Control.csv": (29, 444),
    "result/Subtypes_Cognitive_vs_Control.csv": (84, 444),
    "result/Subtypes_MildPTSD_vs_Control.csv": (81, 444),
    "result/Subtypes_SeverePTSD_vs_Control.csv": (139, 444),
    "result/Cognitive_CogPos_vs_CogNeg.csv": (143, 180),
    "result/Cognitive_CogPos_vs_Control.csv": (143, 444),
    # Viewer source analyses.
    "result_V12/Subtypes_Depressive_vs_Control.csv": (29, 444),
    "result_V12/Subtypes_Cognitive_vs_Control.csv": (84, 444),
    "result_V12/Subtypes_MildPTSD_vs_Control.csv": (81, 444),
    "result_V12/Subtypes_SeverePTSD_vs_Control.csv": (139, 444),
    "result_V12/Cognitive_CogPos_vs_CogNeg.csv": (143, 180),
    "result_V12/Cognitive_CogPos_vs_Control.csv": (143, 444),
    # Pairwise subtype analyses.
    "result_FINAL_PRODUCTION/IPW_Six_Comparisons/Pairwise_Depressive_vs_Cognitive.csv": (29, 84),
    "result_FINAL_PRODUCTION/IPW_Six_Comparisons/Pairwise_Depressive_vs_MildPTSD.csv": (29, 81),
    "result_FINAL_PRODUCTION/IPW_Six_Comparisons/Pairwise_Depressive_vs_SeverePTSD.csv": (29, 139),
    "result_FINAL_PRODUCTION/IPW_Six_Comparisons/Pairwise_Cognitive_vs_MildPTSD.csv": (84, 81),
    "result_FINAL_PRODUCTION/IPW_Six_Comparisons/Pairwise_Cognitive_vs_SeverePTSD.csv": (84, 139),
    "result_FINAL_PRODUCTION/IPW_Six_Comparisons/Pairwise_MildPTSD_vs_SeverePTSD.csv": (81, 139),
    # V12 production aliases.
    "result_FINAL_PRODUCTION/IPW_V12_Six_Comparisons/1_CogPos_vs_CogNeg.csv": (143, 180),
    "result_FINAL_PRODUCTION/IPW_V12_Six_Comparisons/2_CogPos_vs_Control.csv": (143, 444),
    "result_FINAL_PRODUCTION/IPW_V12_Six_Comparisons/3_Depressive_vs_Control.csv": (29, 444),
    "result_FINAL_PRODUCTION/IPW_V12_Six_Comparisons/4_Cognitive_vs_Control.csv": (84, 444),
    "result_FINAL_PRODUCTION/IPW_V12_Six_Comparisons/5_MildPTSD_vs_Control.csv": (81, 444),
    "result_FINAL_PRODUCTION/IPW_V12_Six_Comparisons/6_SeverePTSD_vs_Control.csv": (139, 444),
    "result_FINAL_PRODUCTION/IPW_V12_Six_Comparisons/Pairwise_MildPTSD_vs_SeverePTSD.csv": (81, 139),
    # Discovery analyses use the matching subtype and control cohorts.
    "result_FINAL_PRODUCTION/IPW_Limma/Target_Discovery_DR_IPW_Depressive.csv": (29, 444),
    "result_FINAL_PRODUCTION/IPW_Limma/Target_Discovery_DR_IPW_Cognitive.csv": (84, 444),
    "result_FINAL_PRODUCTION/IPW_Limma/Target_Discovery_DR_IPW_MildPTSD.csv": (81, 444),
    # Causal and robustness analyses.
    "result_Causal/Causal_Depressive_vs_Control.csv": (29, 444),
    "result_Causal/Causal_Cognitive_vs_Control.csv": (84, 444),
    "result_Causal/Causal_MildPTSD_vs_Control.csv": (81, 444),
    "result_Causal/Causal_SeverePTSD_vs_Control.csv": (139, 444),
    "result_Causal/RF_IPW_Depressive_vs_Control.csv": (29, 444),
    "result_Causal/RF_IPW_Cognitive_vs_Control.csv": (84, 444),
    "result_Causal/RF_IPW_MildPTSD_vs_Control.csv": (81, 444),
    "result_Causal/First_Principles/Orthogonal_Depressive_vs_InternalPTSD.csv": (29, 220),
    "result_Causal/First_Principles/Orthogonal_Cognitive_vs_InternalPTSD.csv": (84, 220),
}


def expected_effect(t_stat: float, n1: int, n2: int) -> float:
    n_eff = (n1 * n2) / (n1 + n2)
    return t_stat / math.sqrt(n_eff)


def expected_hedges_g(effect_size: float, n1: int, n2: int) -> float:
    correction = 1 - (3 / (4 * (n1 + n2 - 2) - 1))
    return effect_size * correction


def process_file(relative_path: str, n1: int, n2: int, check_only: bool) -> int:
    path = ROOT / relative_path
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        raw_text = handle.read()
    line_ending = "\r\n" if "\r\n" in raw_text else "\n"
    raw_lines = raw_text.splitlines()
    rows = list(csv.DictReader(raw_lines))
    if not raw_lines or not rows:
        raise ValueError(f"{relative_path} is empty")

    header = next(csv.reader([raw_lines[0]]))
    if "t" not in header:
        raise ValueError(f"{relative_path} does not contain a t column")
    if len(rows) != len(raw_lines) - 1:
        raise ValueError(f"{relative_path} contains multiline rows, which this formatter does not support")
    effect_columns = [name for name in ("effect_size", "hedges_g") if name in header]
    if effect_columns and header[-len(effect_columns):] != effect_columns:
        raise ValueError(f"{relative_path} must keep effect-size columns at the end")

    mismatches = 0
    raw_header = raw_lines[0]
    for field in ("effect_size", "hedges_g"):
        if field not in header:
            raw_header += f',"{field}"'
    output_lines = [raw_header]
    for row_number, (row, raw_line) in enumerate(zip(rows, raw_lines[1:]), start=2):
        raw_t = row.get("t", "").strip()
        if raw_t in {"", "NA", "NaN", "nan"}:
            effect_text = ""
            hedges_text = ""
        else:
            expected = expected_effect(float(raw_t), n1, n2)
            expected_g = expected_hedges_g(expected, n1, n2)
            effect_text = format(expected, ".15g")
            hedges_text = format(expected_g, ".15g")
            raw_effect = row.get("effect_size", "").strip()
            raw_hedges = row.get("hedges_g", "").strip()
            if check_only:
                try:
                    actual = float(raw_effect)
                except ValueError:
                    actual = math.nan
                tolerance = 1e-10 * (1 + abs(expected))
                if not math.isfinite(actual) or abs(actual - expected) > tolerance:
                    print(f"Cohen's d mismatch: {relative_path}:{row_number}")
                    mismatches += 1
                try:
                    actual_g = float(raw_hedges)
                except ValueError:
                    actual_g = math.nan
                g_tolerance = 1e-10 * (1 + abs(expected_g))
                if not math.isfinite(actual_g) or abs(actual_g - expected_g) > g_tolerance:
                    print(f"Hedges' g mismatch: {relative_path}:{row_number}")
                    mismatches += 1
        raw_without_effects = raw_line
        for _ in effect_columns:
            raw_without_effects, separator, _ = raw_without_effects.rpartition(",")
            if not separator:
                raise ValueError(f"{relative_path}:{row_number} is not a valid CSV row")
        output_lines.append(f"{raw_without_effects},{effect_text},{hedges_text}")

    if not check_only:
        temporary_path = path.with_suffix(path.suffix + ".tmp")
        with temporary_path.open("w", encoding="utf-8", newline="") as handle:
            handle.write(line_ending.join(output_lines) + line_ending)
        temporary_path.replace(path)

    return mismatches


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Verify existing values without rewriting files")
    args = parser.parse_args()

    mismatches = 0
    for relative_path, (n1, n2) in FILE_SAMPLE_SIZES.items():
        mismatches += process_file(relative_path, n1, n2, args.check)

    if mismatches:
        raise SystemExit(f"Effect-size validation failed with {mismatches} mismatch(es).")
    action = "Validated" if args.check else "Updated"
    print(f"{action} Cohen's d and Hedges' g in {len(FILE_SAMPLE_SIZES)} differential-analysis files.")


if __name__ == "__main__":
    main()
