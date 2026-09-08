#!/usr/bin/env python3
"""
Research Planner CLI for SUSENAS Research Discovery Engine.

Usage:
  python cli/research.py "anak balita dan kerawanan pangan"
  python cli/research.py research/rq001_balita_kerawanan_pangan.yaml
"""

import sys
import os
import json
from pathlib import Path

# Ensure root is in python path
ROOT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT_DIR))

from engine.planner import ResearchPlanner

def format_terminal_output(plan: dict) -> str:
    lines = []
    lines.append("")
    lines.append("Research Summary")
    lines.append("??????????????????????????????????????????????????")

    # Concepts
    lines.append("Concepts")
    if plan["concepts"]:
        for c in plan["concepts"]:
            c_label = c.replace("_", " ").title()
            lines.append(f"  ? {c_label}")
    else:
        lines.append("  (None matched)")
    lines.append("")

    # Supporting Papers
    lines.append("Supporting Papers")
    if plan["supporting_papers"]:
        for p in plan["supporting_papers"]:
            authors_short = p['authors'].split(",")[0] + " et al." if "," in p['authors'] else p['authors']
            lines.append(f"  ? {authors_short} ({p['year']}) - \"{p['title'][:60]}...\"")
    else:
        lines.append("  (No direct literature citation indexed)")
    lines.append("")

    # Variables
    lines.append(f"Variables ({plan['matched_features_count']} matched cross-year features)")
    shown_vars = plan["candidate_variables"][:8]
    for v in shown_vars:
        lines.append(f"  ? {v}")
    if len(plan["candidate_variables"]) > 8:
        lines.append(f"  ... (+{len(plan['candidate_variables']) - 8} more variables)")
    lines.append("")

    # Years
    y_min, y_max = min(plan["years"]), max(plan["years"])
    lines.append("Years")
    lines.append(f"  {y_min}?{y_max}")
    lines.append("")

    # Files Needed
    lines.append("Files Needed")
    for m in plan["required_modules"]:
        lines.append(f"  ? {m.upper()}")
    lines.append("")

    # Local vs Missing Status
    resolver = plan["resolver"]
    missing_files = [f for f in resolver["files"] if f["status"] == "Missing"]
    local_files = [f for f in resolver["files"] if f["status"] == "Local"]

    if local_files:
        lines.append(f"Available Locally ({len(local_files)} files)")
        for f in local_files[:4]:
            lines.append(f"  ? {f['module'].upper()} {f['year']}")
        if len(local_files) > 4:
            lines.append(f"  ... (+{len(local_files) - 4} more files)")
        lines.append("")

    if missing_files:
        lines.append(f"Missing Local ({len(missing_files)} files to download from Google Drive)")
        for f in missing_files[:6]:
            lines.append(f"  ? {f['module'].upper()} {f['year']} ({f['file_needed'][:45]}...)")
        if len(missing_files) > 6:
            lines.append(f"  ... (+{len(missing_files) - 6} more files)")
        lines.append("")
    else:
        lines.append("Local Files Status")
        lines.append("  ? All required survey files are available locally!")
        lines.append("")

    # Generated Files
    lines.append("Generated Files")
    lines.append(f"  {plan['feature_master_path']}")
    lines.append(f"  {plan['etl_script_path']}")
    lines.append("??????????????????????????????????????????????????")
    lines.append("")
    return "\n".join(lines)

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python cli/research.py \"<research question or prompt>\"")
        print("  python cli/research.py <path/to/research.yaml>")
        sys.exit(1)

    arg = sys.argv[1]
    planner = ResearchPlanner()

    if arg.endswith(".yaml") or arg.endswith(".yml"):
        yaml_p = Path(arg)
        if not yaml_p.exists():
            print(f"[ERROR] YAML file not found: {yaml_p}")
            sys.exit(1)
        plan = planner.plan_from_yaml(yaml_p)
    else:
        plan = planner.plan_from_query(arg)

    if "--json" in sys.argv:
        print(json.dumps(plan, indent=2))
    else:
        print(format_terminal_output(plan))

if __name__ == "__main__":
    main()
