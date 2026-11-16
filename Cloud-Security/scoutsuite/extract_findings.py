#!/usr/bin/env python3
"""Print every ScoutSuite Azure finding that flagged >0 items, grouped by service.

Usage: python3 extract_findings.py <report-dir>
ScoutSuite writes results as a JS file: scoutsuite-results/scoutsuite_results_azure-*.js
"""
import glob
import json
import os
import sys


def load_results(report_dir):
    pattern = os.path.join(report_dir, "**", "scoutsuite_results_*.js")
    files = sorted(glob.glob(pattern, recursive=True))
    if not files:
        sys.exit(f"No scoutsuite_results_*.js found under {report_dir}")
    with open(files[-1], encoding="utf-8") as fh:
        fh.readline()  # first line is 'scoutsuite_results ='
        return json.load(fh)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    data = load_results(sys.argv[1])
    rows = []
    for svc_name, svc in data.get("services", {}).items():
        for rule_id, f in (svc.get("findings") or {}).items():
            if f.get("flagged_items", 0) > 0:
                rows.append((f.get("level", "?"), svc_name, rule_id,
                             f.get("flagged_items"), f.get("description", "")))
    order = {"danger": 0, "warning": 1}
    rows.sort(key=lambda r: (order.get(r[0], 2), r[1]))
    print(f"{'LEVEL':8} {'SERVICE':22} {'FLAGGED':>7}  DESCRIPTION")
    for level, svc, rule, n, desc in rows:
        print(f"{level:8} {svc:22} {n:>7}  {desc}  [{rule}]")


if __name__ == "__main__":
    main()
