#!/usr/bin/env python3
"""Generate the painted art for a set of assets in parallel.

    python3 tools/art/gen_slice.py <set-name>

Sets are defined in tools/art/sets.py.
"""
import sys
import os
import concurrent.futures as cf
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rep
import sets


def job(a):
    kind = a.get("kind", "image")
    try:
        if kind == "image":
            rep.image(a["out"], a["prompt"], a.get("aspect", "16:9"), a.get("ultra", False), a.get("seed"), a.get("style", True), a.get("raw", False))
        if a.get("cutout"):
            rep.cutout(a["out"], a["cutout"])
        return a["out"], None
    except Exception as e:
        return a["out"], str(e)


if __name__ == "__main__":
    items = []
    for name in sys.argv[1:]:
        items += getattr(sets, name)()
    with cf.ThreadPoolExecutor(max_workers=8) as ex:
        for out, err in ex.map(job, items):
            print(("FAIL " + out + ": " + err) if err else ("ok " + out), flush=True)
