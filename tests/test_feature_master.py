from pathlib import Path
from engine.feature_master import generate_feature_master

def test_generate_feature_master():
    test_vars = ["URUT", "R102", "R105", "WERT", "R407", "R1701", "KALORI_KAP", "FOOD"]
    out_file = Path("reports/test_feature_master.md")
    res = generate_feature_master(test_vars, output_path=out_file)
    
    assert res["total_matched_features"] > 0
    assert out_file.exists()
    
    content = out_file.read_text(encoding="utf-8")
    assert "| Konsep / Fitur |" in content
    assert "2019" in content and "2023" in content
    
    # Cleanup test artifact
    out_file.unlink(missing_ok=True)
