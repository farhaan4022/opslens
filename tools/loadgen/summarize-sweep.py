#!/usr/bin/env python3

import argparse
import csv
import json
import statistics
from pathlib import Path


def average(values):
    return statistics.mean(values) if values else None


def main():

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "root",
        type=Path
    )

    parser.add_argument(
        "--output",
        type=Path,
        required=True
    )

    args = parser.parse_args()

    rows = []

    for directory in sorted(
        args.root.glob("c*"),
        key=lambda x: int(x.name[1:])
    ):

        concurrency = int(directory.name[1:])

        summaries = []

        for file in directory.glob(
            "run*/summary.json"
        ):

            with file.open() as f:
                summaries.append(json.load(f))

        if not summaries:
            continue

        rows.append({

            "concurrency": concurrency,

            "runs": len(summaries),

            "success_rate_pct":
                average(
                    [
                        x["success_rate_pct"]
                        for x in summaries
                    ]
                ),

            "throughput_rps":
                average(
                    [
                        x["throughput_rps"]
                        for x in summaries
                    ]
                ),

            "p50_s":
                average(
                    [
                        x["latency_successful_s"]["p50"]
                        for x in summaries
                    ]
                ),

            "p95_s":
                average(
                    [
                        x["latency_successful_s"]["p95"]
                        for x in summaries
                    ]
                ),

            "p99_s":
                average(
                    [
                        x["latency_successful_s"]["p99"]
                        for x in summaries
                    ]
                )
        })


    args.output.parent.mkdir(
        parents=True,
        exist_ok=True
    )

    fields = [
        "concurrency",
        "runs",
        "success_rate_pct",
        "throughput_rps",
        "p50_s",
        "p95_s",
        "p99_s"
    ]


    with args.output.open(
        "w",
        newline=""
    ) as f:

        writer = csv.DictWriter(
            f,
            fieldnames=fields
        )

        writer.writeheader()

        for row in rows:
            writer.writerow(row)


if __name__ == "__main__":
    main()
