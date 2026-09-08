from pathlib import Path
from engine.etl_generator import generate_lazy_etl_r

def test_generate_lazy_etl():
    test_cols = {
        2020: {"kor_rt": ["URUT", "R102", "R105", "WERT", "R1601"], "kp_bp43": ["URUT", "FOOD"]},
        2023: {"kor_rt": ["URUT", "R102", "R105", "WERT", "R1701"], "kp_bp43": ["URUT", "FOOD"]}
    }
    out_script = Path("etl/generated/test_extract.R")
    p = generate_lazy_etl_r("test_rq", "Test Title", [2020, 2023], ["kor_rt", "kp_bp43"], test_cols, output_file=out_script)
    
    assert p.exists()
    content = p.read_text(encoding="utf-8")
    assert "select = c(" in content or "col_select" in content
    assert "data.table::fread" in content
    assert "Reduce" in content # join
    
    # Cleanup
    out_script.unlink(missing_ok=True)
