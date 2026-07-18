from datetime import datetime as dt
from timetrack import intervals as I

def S(h1,m1,h2,m2): return (dt(2026,7,18,h1,m1), dt(2026,7,18,h2,m2))

def test_merge_overlapping():
    assert I.merge([S(9,0,10,0), S(9,30,11,0)]) == [ (dt(2026,7,18,9,0), dt(2026,7,18,11,0)) ]

def test_overlap_seconds():
    assert I.overlap([S(9,0,10,0)], [S(9,30,10,30)]) == 30*60

def test_subtract():
    assert I.subtract([S(9,0,11,0)], [S(9,30,10,0)]) == [ S(9,0,9,30), S(10,0,11,0) ]
