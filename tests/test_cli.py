import subprocess
import json

def test_cli_query_mode():
    cmd = ["python", "cli/research.py", "anak balita dan kerawanan pangan", "--json"]
    proc = subprocess.run(cmd, capture_output=True, text=True, check=True)
    plan = json.loads(proc.stdout)
    
    assert "children_under5" in plan["concepts"]
    assert "food_insecurity" in plan["concepts"]
    assert len(plan["candidate_variables"]) > 0
    assert plan["matched_features_count"] > 0

def test_cli_yaml_mode():
    cmd = ["python", "cli/research.py", "research/rq001_balita_kerawanan_pangan.yaml", "--json"]
    proc = subprocess.run(cmd, capture_output=True, text=True, check=True)
    plan = json.loads(proc.stdout)
    
    assert plan["rq_id"] == "rq001"
    assert "children_under5" in plan["concepts"]
    assert len(plan["required_modules"]) > 0
