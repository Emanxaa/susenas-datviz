#!/usr/bin/env python3
"""
Drive Resolver for SUSENAS Research Discovery Engine.

Resolves required survey datasets against survey_catalog in metadata.db
and checks local filesystem availability (Local vs Missing vs Unknown).
"""

import sqlite3
from pathlib import Path
from typing import List, Dict, Any, Optional

METADATA_DB = Path("database/metadata.db")

# Local search candidate directories
LOCAL_DATA_ROOTS = [
    Path("SUSENAS/JAWA BARAT"),
    Path("Jawa Barat"),
    Path("SUSENAS")
]

def resolve_files(
    required_modules: List[str],
    years: Optional[List[int]] = None
) -> Dict[str, Any]:
    """Resolve required modules across survey years against survey_catalog and local disk."""
    if years is None:
        years = [2019, 2020, 2021, 2022, 2023]

    conn = sqlite3.connect(METADATA_DB)
    cur = conn.cursor()

    results = []
    local_count = 0
    missing_count = 0
    unknown_count = 0

    norm_modules = set()
    for m in required_modules:
        m_clean = m.lower().strip()
        if 'kor_rt' in m_clean or ('kor' in m_clean and 'rt' in m_clean):
            norm_modules.add('kor_rt')
        if 'kor_individu' in m_clean or 'kor_ind' in m_clean or 'ind1' in m_clean:
            norm_modules.add('kor_ind1')
        if 'bp43' in m_clean or 'kp_bp43' in m_clean:
            norm_modules.add('kp_bp43')
        if 'bp41' in m_clean or 'kp_bp41' in m_clean:
            norm_modules.add('kp_bp41')
        if 'bp42' in m_clean or 'kp_bp42' in m_clean:
            norm_modules.add('kp_bp42')

    if not norm_modules:
        norm_modules = {'kor_rt', 'kp_bp43'}

    for yr in years:
        for mod in sorted(list(norm_modules)):
            q = """
                SELECT year, module, file_name, file_format, file_path
                FROM survey_catalog
                WHERE year = ? AND module = ?
            """
            row = cur.execute(q, (yr, mod)).fetchone()

            if row:
                yr_val, mod_val, fname, fmt, fpath = row
                file_needed = fname if fname else f"{mod}_{yr}.{fmt}"

                found_local = False
                for root in LOCAL_DATA_ROOTS:
                    yr_dir = root / str(yr)
                    if yr_dir.exists():
                        for local_file in yr_dir.glob('**/*'):
                            if local_file.is_file():
                                if fname and (fname.lower() in local_file.name.lower() or local_file.stem.lower() in fname.lower()):
                                    found_local = True
                                    break
                                elif mod in local_file.name.lower():
                                    found_local = True
                                    break
                    if found_local:
                        break

                status = 'Local' if found_local else 'Missing'
                if status == 'Local':
                    local_count += 1
                else:
                    missing_count += 1

                results.append({
                    "year": yr,
                    "module": mod,
                    "file_needed": file_needed,
                    "status": status
                })
            else:
                unknown_count += 1
                results.append({
                    "year": yr,
                    "module": mod,
                    "file_needed": f"{mod}_{yr}.csv",
                    "status": "Unknown"
                })

    conn.close()

    return {
        "total_files": len(results),
        "local_count": local_count,
        "missing_count": missing_count,
        "unknown_count": unknown_count,
        "files": results
    }

def format_resolver_markdown(resolver_res: Dict[str, Any]) -> str:
    """Format resolver output as markdown table."""
    lines = [
        "| Year | Module | File Needed | Status |",
        "|:---:|:---|:---|:---:|"
    ]
    for f in resolver_res['files']:
        badge = 'Local' if f['status'] == 'Local' else ('Missing' if f['status'] == 'Missing' else 'Unknown')
        lines.append(f"| {f['year']} | `{f['module']}` | {f['file_needed']} | {badge} |")
    return '\n'.join(lines)

if __name__ == "__main__":
    res = resolve_files(['kor_rt', 'kp_bp43'], [2019, 2020, 2021, 2022, 2023])
    print(f"Total: {res['total_files']} | Local: {res['local_count']} | Missing: {res['missing_count']}")
    print(format_resolver_markdown(res))
