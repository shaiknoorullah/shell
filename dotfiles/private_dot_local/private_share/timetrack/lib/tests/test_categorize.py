from timetrack import categorize

RULES = [
    {"category": "Salah", "match_title": "salah|asr"},
    {"category": "Infra", "match_title": "ovh|k8s|kubectl|cluster"},
    {"category": "Code", "match_title": "dots|nvim", "match_domain": "github"},
    {"category": "Comms", "match_app": "slack|teams"},
    {"category": "Web", "match_app": "brave|firefox"},
]

def test_first_match_wins_title():
    assert categorize.categorize("kitty", "ovh-deployment cluster", rules=RULES) == "Infra"

def test_app_rule():
    assert categorize.categorize("slack", "anything", rules=RULES) == "Comms"

def test_domain_rule_beats_generic_web():
    # a github domain in Brave -> Code (rule order), not Web
    assert categorize.categorize("brave", "PR #12", domain="github.com", rules=RULES) == "Code"

def test_unmatched_is_uncategorized():
    assert categorize.categorize("kitty", " random musing", rules=RULES) == "Uncategorized"
