#!/usr/bin/env python3

import csv
import json
import re
import statistics
from collections import defaultdict
from pathlib import Path

ROOT = Path("experiments/baseline/006-resource-constraints")
OUTPUT = ROOT / "memory-summary.csv"

pattern = re.compile(
    r"mem-(unlimited|1g|512m|256m)-r(\d+)$"
)

memory_order = {
    "unlimited": 0,
    "1g": 1,
    "512m": 2,
    "256m": 3,
}


def read_events(path):
    values = {}

    if not path.exists():
        return values

    for line in path.read_text().splitlines():
        parts = line.split()

        if len(parts) == 2:
            try:
                values[parts[0]] = int(parts[1])
            except ValueError:
                pass

    return values


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

        memory = match.group(1)

        summary_path = run_dir / "loadgen" / "summary.json"

        if not summary_path.exists():
            continue

        with summary_path.open() as f:
            summary = json.load(f)

        before = read_events(
            run_dir / "memory-events-before.txt"
        )

        after = read_events(
            run_dir / "memory-events-after.txt"
        )

        oom_kill_delta = max(
            after.get("oom_kill", 0)
            - before.get("oom_kill", 0),
            0
        )

        state_path = run_dir / "container-state.txt"

        state = (
            state_path.read_text()
            if state_path.exists()
            else ""
        )

        groups[(engine, memory)].append({
            "summary": summary,
            "oom_kill_delta": oom_kill_delta,
            "oom_flagged": "oom_killed=true" in state,
        })


rows = []

for (engine, memory), runs in groups.items():

    summaries = [x["summary"] for x in runs]

    request_count = sum(
        x["request_count"] for x in summaries
    )

    success_count = sum(
        x["success_count"] for x in summaries
    )

    failure_count = sum(
        x["failure_count"] for x in summaries
    )

    success_rate = (
        success_count / request_count * 100
        if request_count else 0
    )

    throughputs = [
        x["throughput_rps"] for x in summaries
    ]

    all_successful = failure_count == 0

    if all_successful:
        p50 = statistics.mean(
            x["latency_successful_s"]["p50"]
            for x in summaries
        )
        p95 = statistics.mean(
            x["latency_successful_s"]["p95"]
            for x in summaries
        )
        p99 = statistics.mean(
            x["latency_successful_s"]["p99"]
            for x in summaries
        )
    else:
        # Successful-request latency is not representative
        # when almost the entire workload failed.
        p50 = ""
        p95 = ""
        p99 = ""

    rows.append({
        "engine": engine,
        "memory": memory,
        "runs": len(runs),
        "requests": request_count,
        "successes": success_count,
        "failures": failure_count,
        "success_rate_pct": round(success_rate, 2),
        "throughput_mean_rps": round(
            statistics.mean(throughputs), 3
        ),
        "throughput_stdev_rps": round(
            statistics.stdev(throughputs)
            if len(throughputs) > 1 else 0,
            3
        ),
        "p50_mean_s": (
            round(p50, 3) if p50 != "" else ""
        ),
        "p95_mean_s": (
            round(p95, 3) if p95 != "" else ""
        ),
        "p99_mean_s": (
            round(p99, 3) if p99 != "" else ""
        ),
        "oom_kill_delta_total": sum(
            x["oom_kill_delta"] for x in runs
        ),
        "runs_oom_flagged": sum(
            1 for x in runs if x["oom_flagged"]
        ),
    })


rows.sort(
    key=lambda r: (
        r["engine"],
        memory_order[r["memory"]]
    )
)

fields = [
    "engine",
    "memory",
    "runs",
    "requests",
    "successes",
    "failures",
    "success_rate_pct",
    "throughput_mean_rps",
    "throughput_stdev_rps",
    "p50_mean_s",
    "p95_mean_s",
    "p99_mean_s",
    "oom_kill_delta_total",
    "runs_oom_flagged",
]

with OUTPUT.open("w", newline="") as f:
    writer = csv.DictWriter(
        f,
        fieldnames=fields
    )
    writer.writeheader()
    writer.writerows(rows)

print(f"Wrote {OUTPUT}")
