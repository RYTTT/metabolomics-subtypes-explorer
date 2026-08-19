#!/usr/bin/env python3
"""Add or verify Cohen's d estimates in differential-analysis CSV outputs."""

import argparse
import csv
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

FILE_SAMPLE_SIZES = {
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
}


def expected_effect(t_stat: float, n1: int, n2: int) -> float:
    n_eff = (n1 * n2) / (n1 + n2)
    return t_stat / math.sqrt(n_eff)


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
    has_effect_size = "effect_size" in header
    if has_effect_size and header[-1] != "effect_size":
        raise ValueError(f"{relative_path} must keep effect_size as its final column")

    mismatches = 0
    output_lines = [raw_lines[0] if has_effect_size else f'{raw_lines[0]},"effect_size"']
    for row_number, (row, raw_line) in enumerate(zip(rows, raw_lines[1:]), start=2):
        raw_t = row.get("t", "").strip()
        if raw_t in {"", "NA", "NaN", "nan"}:
            expected_text = ""
        else:
            expected = expected_effect(float(raw_t), n1, n2)
            expected_text = format(expected, ".15g")
            raw_effect = row.get("effect_size", "").strip()
            if check_only:
                try:
                    actual = float(raw_effect)
                except ValueError:
                    actual = math.nan
                tolerance = 1e-10 * (1 + abs(expected))
                if not math.isfinite(actual) or abs(actual - expected) > tolerance:
                    print(f"Mismatch: {relative_path}:{row_number}")
                    mismatches += 1
        if has_effect_size:
            raw_without_effect, separator, _ = raw_line.rpartition(",")
            if not separator:
                raise ValueError(f"{relative_path}:{row_number} is not a valid CSV row")
            output_lines.append(f"{raw_without_effect},{expected_text}")
        else:
            output_lines.append(f"{raw_line},{expected_text}")

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
    print(f"{action} Cohen's d in {len(FILE_SAMPLE_SIZES)} differential-analysis files.")


if __name__ == "__main__":
    main()
