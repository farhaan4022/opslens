#!/usr/bin/env python3

import csv
import json
import statistics
from pathlib import Path


ROOT = Path(
    "experiments/baseline/008-scaling-capacity"
)

OUTPUT = ROOT / "scaling-summary.csv"


rows = []


for replica_dir in sorted(ROOT.glob("replicas-*")):

    replica_count = int(
        replica_dir.name.split("-")[1]
    )

    for engine in [
        "chromium",
        "libreoffice"
    ]:

        summary = (
            replica_dir /
            "mixed" /
            engine /
            "summary.json"
        )

        if not summary.exists():
            continue


        with summary.open() as f:
            data = json.load(f)


        latency = data.get(
            "latency_successful_s",
            {}
        )


        rows.append({

            "replicas": replica_count,

            "engine": engine,

            "requests":
                data.get(
                    "request_count",
                    0
                ),

            "success_rate_pct":
                data.get(
                    "success_rate_pct",
                    0
                ),

            "throughput_rps":
                round(
                    data.get(
                        "throughput_rps",
                        0
                    ),
                    3
                ),

            "p50_latency_s":
                round(
                    latency.get(
                        "p50",
                        0
                    ),
                    3
                ),

            "p95_latency_s":
                round(
                    latency.get(
                        "p95",
                        0
                    ),
                    3
                ),

            "p99_latency_s":
                round(
                    latency.get(
                        "p99",
                        0
                    ),
                    3
                )

        })


with OUTPUT.open(
    "w",
    newline=""
) as f:

    writer = csv.DictWriter(
        f,
        fieldnames=rows[0].keys()
    )

    writer.writeheader()

    writer.writerows(
        rows
    )


print(
    f"Wrote {OUTPUT}"
)

