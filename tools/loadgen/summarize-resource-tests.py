#!/usr/bin/env python3

import csv
import json
import re
import statistics
from collections import defaultdict
from pathlib import Path

ROOT = Path("experiments/baseline/006-resource-constraints")
OUTPUT = ROOT / "cpu-summary.csv"

pattern = re.compile(r"cpu-(unlimited|4|2|1|0p5)-r(\d+)$")

cpu_names = {
    "unlimited": "unlimited",
    "4": "4",
    "2": "2",
    "1": "1",
    "0p5": "0.5",
}

cpu_order = {
    "unlimited": 0,
    "4": 1,
    "2": 2,
    "1": 3,
    "0.5": 4,
}

groups = defaultdict(list)

for engine_dir in ROOT.iterdir():
    if not engine_dir.is_dir():
        continue

    engine = engine_dir.name

    for run_dir in engine_dir.iterdir():
        if not run_dir.is_dir():
            continue

        match = pattern.fullmatch(run_dir.name)
        if not match:
            continue

        cpu_key = match.group(1)
        summary_file = run_dir / "loadgen" / "summary.json"

        if not summary_file.exists():
            continue

        with summary_file.open() as f:
            summary = json.load(f)

        groups[(engine, cpu_names[cpu_key])].append(summary)


rows = []

for (engine, cpu), runs in groups.items():

    throughput = [r["throughput_rps"] for r in runs]
    success = [r["success_rate_pct"] for r in runs]
    p50 = [r["latency_successful_s"]["p50"] for r in runs]
    p95 = [r["latency_successful_s"]["p95"] for r in runs]
    p99 = [r["latency_successful_s"]["p99"] for r in runs]

    rows.append({
        "engine": engine,
        "cpu": cpu,
        "runs": len(runs),
        "success_rate_pct": round(statistics.mean(success), 3),
        "throughput_mean_rps": round(statistics.mean(throughput), 3),
        "throughput_stdev_rps": round(
            statistics.stdev(throughput) if len(throughput) > 1 else 0,
            3
        ),
        "p50_mean_s": round(statistics.mean(p50), 3),
        "p95_mean_s": round(statistics.mean(p95), 3),
        "p99_mean_s": round(statistics.mean(p99), 3),
    })


rows.sort(
    key=lambda r: (
        r["engine"],
        cpu_order[r["cpu"]]
    )
)

fields = [
    "engine",
    "cpu",
    "runs",
    "success_rate_pct",
    "throughput_mean_rps",
    "throughput_stdev_rps",
    "p50_mean_s",
    "p95_mean_s",
    "p99_mean_s",
]

with OUTPUT.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fields)
    writer.writeheader()
    writer.writerows(rows)

print(f"Wrote {OUTPUT}")
