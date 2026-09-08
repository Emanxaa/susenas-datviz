#!/usr/bin/env python3
"""
Research Planner Orchestrator for SUSENAS Research Discovery Engine.

Coordinates:
  1. Concept Mapping (NLP query or YAML spec -> concepts & variables)
  2. Literature Evidence Retrieval (evidence.db)
  3. Cross-Year Compatibility Matrix (Feature Master Generator)
  4. Google Drive Catalog & Local Resolution (Drive Resolver)
  5. Lazy Selective ETL Code Generation (ETL Generator)
"""

import os
import re
import yaml
from pathlib import Path
from typing import Dict, List, Any, Optional

from concept_mapper import map_query
from engine.feature_master import generate_feature_master
from engine.drive_resolver import resolve_files
from engine.etl_generator import generate_lazy_etl_r

class ResearchPlanner:
    def __init__(self, metadata_db: str = "database/metadata.db", evidence_db: str = "database/evidence.db"):
        self.metadata_db = Path(metadata_db)
        self.evidence_db = Path(evidence_db)

    def plan_from_yaml(self, yaml_path: Path) -> Dict[str, Any]:
        """Execute full research planning from a YAML specification."""
        with open(yaml_path, "r", encoding="utf-8") as f:
            spec = yaml.safe_load(f)

        rq_id = spec.get("id", yaml_path.stem)
        title = spec.get("title", "Untitled Research")
        question = spec.get("question", "")
        concepts = spec.get("concepts", [])
        years = spec.get("years", [2019, 2020, 2021, 2022, 2023])

        # Gather explicitly requested variables
        explicit_vars = []
        var_spec = spec.get("variables", {})
        if isinstance(var_spec, dict):
            for group, vlist in var_spec.items():
                if isinstance(vlist, list):
                    for item in vlist:
                        # Clean variable name
                        if isinstance(item, str):
                            v_clean = item.split()[0].replace(",", "").strip()
                            explicit_vars.append(v_clean)
                        elif isinstance(item, dict):
                            for k in item.keys():
                                explicit_vars.append(str(k).split()[0].replace(",", "").strip())
        elif isinstance(var_spec, list):
            explicit_vars = var_spec

        # Combine question and title for concept mapping
        combined_text = f"{title} {question} {' '.join(concepts)}"
        mapping_res = map_query(combined_text)

        # Merge concepts
        merged_concepts = sorted(list(set(concepts + mapping_res["concepts"])))

        # Merge candidate variables
        all_candidate_vars = sorted(list(set(explicit_vars + mapping_res["candidate_variables"])))

        return self._build_plan(
            rq_id=rq_id,
            title=title,
            question=question,
            concepts=merged_concepts,
            candidate_vars=all_candidate_vars,
            supporting_papers=mapping_res["supporting_papers"],
            years=years
        )

    def plan_from_query(self, query_text: str, rq_id: str = "rq_query") -> Dict[str, Any]:
        """Execute full research planning from a free-text research prompt."""
        mapping_res = map_query(query_text)
        title = f"Riset: {query_text.title()}"
        years = [2019, 2020, 2021, 2022, 2023]

        return self._build_plan(
            rq_id=rq_id,
            title=title,
            question=query_text,
            concepts=mapping_res["concepts"],
            candidate_vars=mapping_res["candidate_variables"],
            supporting_papers=mapping_res["supporting_papers"],
            years=years
        )

    def _build_plan(
        self,
        rq_id: str,
        title: str,
        question: str,
        concepts: List[str],
        candidate_vars: List[str],
        supporting_papers: List[Dict[str, Any]],
        years: List[int]
    ) -> Dict[str, Any]:
        # 1. Feature Master
        fm_report_path = Path("reports") / "feature_master.md"
        rq_fm_report_path = Path("reports") / f"{rq_id}_feature_master.md"
        fm_res = generate_feature_master(candidate_vars, concepts, output_path=fm_report_path)
        # Also save specific copy
        with open(rq_fm_report_path, "w", encoding="utf-8") as f:
            f.write(fm_res["markdown"])

        # 2. Identify required modules from matched features
        required_modules = set()
        year_columns = {yr: {} for yr in years}

        for row in fm_res["rows"]:
            mod_str = row["module"].lower()
            mods = [m.strip() for m in mod_str.split("/") if m.strip()]
            for m in mods:
                if "kor_rt" in m or ("kor" in m and "rt" in m):
                    target_mod = "kor_rt"
                elif "kor_ind" in m or "individu" in m:
                    target_mod = "kor_ind1"
                elif "bp43" in m:
                    target_mod = "kp_bp43"
                elif "bp41" in m:
                    target_mod = "kp_bp41"
                elif "bp42" in m:
                    target_mod = "kp_bp42"
                else:
                    target_mod = "kor_rt"

                required_modules.add(target_mod)

                for yr in years:
                    col_key = f"var_{yr}"
                    col_val = row.get(col_key, "")
                    # Extract variable code if valid
                    clean_col = col_val.split()[0].replace(",", "").split("/")[0].split("-")[0].strip()
                    if clean_col and clean_col not in ["-", "N/A"]:
                        year_columns[yr].setdefault(target_mod, set()).add(clean_col)

        # Ensure URUT is in all modules
        for yr in years:
            for mod in year_columns[yr]:
                year_columns[yr][mod].add("URUT")
                year_columns[yr][mod] = sorted(list(year_columns[yr][mod]))

        # Default fallback modules if none matched
        if not required_modules:
            required_modules = {"kor_rt", "kp_bp43"}

        sorted_modules = sorted(list(required_modules))

        # 3. Drive Resolver
        resolver_res = resolve_files(sorted_modules, years)

        # 4. Lazy ETL Generator
        etl_script_path = generate_lazy_etl_r(
            rq_id=rq_id,
            title=title,
            years=years,
            modules=sorted_modules,
            year_columns=year_columns
        )

        return {
            "rq_id": rq_id,
            "title": title,
            "question": question,
            "concepts": concepts,
            "candidate_variables": candidate_vars,
            "matched_features_count": fm_res["total_matched_features"],
            "supporting_papers": supporting_papers,
            "years": years,
            "required_modules": sorted_modules,
            "resolver": resolver_res,
            "feature_master_path": str(fm_report_path).replace("\\", "/"),
            "rq_feature_master_path": str(rq_fm_report_path).replace("\\", "/"),
            "etl_script_path": str(etl_script_path).replace("\\", "/")
        }
