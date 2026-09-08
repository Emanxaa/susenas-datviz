from concept_mapper import map_query

def test_mapping_balita_and_fies():
    # Scenario 1 from Acceptance Criteria
    res = map_query("balita dan kerawanan pangan")
    assert "children_under5" in res["concepts"], "Must match children_under5"
    assert "food_insecurity" in res["concepts"], "Must match food_insecurity"
    assert len(res["candidate_variables"]) > 0, "Must return candidate variables"
    assert "R407" in res["candidate_variables"] or "JART014" in res["candidate_variables"]

def test_mapping_bansos_and_fies():
    # Scenario 2 from Acceptance Criteria
    res = map_query("bansos dan kerawanan pangan")
    assert "social_assistance" in res["concepts"], "Must match social_assistance"
    assert "food_insecurity" in res["concepts"], "Must match food_insecurity"
    assert "R2207" in res["candidate_variables"] or "R1202A" in res["candidate_variables"] or "R2204A" in res["candidate_variables"]

def test_mapping_wash_sanitasi():
    res = map_query("air bersih dan sanitasi layak")
    assert "water_sanitation" in res["concepts"]
    assert any(v in res["candidate_variables"] for v in ["R1809A", "R1810A"])
