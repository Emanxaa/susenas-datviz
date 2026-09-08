from engine.drive_resolver import resolve_files

def test_drive_resolver_returns_valid_status():
    res = resolve_files(["kor_rt", "kp_bp43"], [2019, 2020, 2021, 2022, 2023])
    assert res["total_files"] == 10
    for f in res["files"]:
        assert f["status"] in ["Local", "Missing", "Unknown"]
        assert f["module"] in ["kor_rt", "kp_bp43"]
        assert 2019 <= f["year"] <= 2023
