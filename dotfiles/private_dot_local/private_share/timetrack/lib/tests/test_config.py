from datetime import datetime, date
from timetrack.config import logical_date

def test_before_4am_belongs_to_previous_day():
    assert logical_date(datetime(2026, 7, 18, 3, 59)) == date(2026, 7, 17)

def test_at_or_after_4am_is_same_day():
    assert logical_date(datetime(2026, 7, 18, 4, 0)) == date(2026, 7, 18)
    assert logical_date(datetime(2026, 7, 18, 23, 30)) == date(2026, 7, 18)
