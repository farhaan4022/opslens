#!/usr/bin/env python3

import csv
import json
import statistics
from pathlib import Path
from collections import defaultdict


ROOT = Path(
    "experiments/baseline/007-engine-interference/formal"
)

OUTPUT = (
    ROOT.parent /
    "interference-summary.csv"
)


groups = defaultdict(list)


for case in ROOT.iterdir():

    if not case.is_dir():
        continue

    parts = case.name.split("-")

    if len(parts) != 3:
        continue

    arch, mode, repeat = parts

    for engine in ["chromium", "libreoffice"]:

        summary = case / engine / "summary.json"

        if not summary.exists():
            continue

        with summary.open() as f:
            data = json.load(f)

        groups[(arch, mode, engine)].append(data)


rows = []

for (arch, mode, engine), values in sorted(groups.items()):

    throughput = [
        x["throughput_rps"]
        for x in values
    ]

    p95 = [
        x["latency_successful_s"]["p95"]
        for x in values
    ]

    success = [
        x["success_rate_pct"]
        for x in values
    ]

    rows.append({
        "architecture": arch,
        "mode": mode,
        "engine": engine,
        "runs": len(values),
        "success_rate_pct_mean": round(statistics.mean(success), 3),
        "throughput_mean_rps": round(statistics.mean(throughput), 3),
        "throughput_stdev": round(
            statistics.stdev(throughput), 3
        ) if len(throughput) > 1 else 0,
        "p95_mean_s": round(statistics.mean(p95), 3)
    })


with OUTPUT.open("w", newline="") as f:

    writer = csv.DictWriter(
        f,
        fieldnames=rows[0].keys()
    )

    writer.writeheader()
    writer.writerows(rows)


print("Wrote:", OUTPUT)
