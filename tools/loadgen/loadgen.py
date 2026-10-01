#!/usr/bin/env python3

import argparse
import csv
import json
import math
import mimetypes
import sys
import time
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests


ENDPOINTS = {
    "chromium": "/forms/chromium/convert/html",
    "libreoffice": "/forms/libreoffice/convert",
}


def percentile(values, p):
    """Return a linearly interpolated percentile."""
    if not values:
        return None

    values = sorted(values)

    if len(values) == 1:
        return values[0]

    position = (len(values) - 1) * (p / 100.0)
    lower = math.floor(position)
    upper = math.ceil(position)

    if lower == upper:
        return values[lower]

    fraction = position - lower

    return (
        values[lower]
        + (values[upper] - values[lower]) * fraction
    )


def perform_request(
    request_id,
    engine,
    target_url,
    fixture,
    wait_delay,
    timeout,
    run_id,
    benchmark_start,
):
    trace_id = f"opslens-{run_id}-{request_id:04d}"

    endpoint = ENDPOINTS[engine]
    url = f"{target_url.rstrip('/')}{endpoint}"

    started = time.perf_counter()

    result = {
        "request_id": request_id,
        "trace_id": trace_id,
        "start_offset_s": started - benchmark_start,
        "status_code": None,
        "success": False,
        "latency_s": None,
        "size_bytes": 0,
        "valid_pdf": False,
        "error": "",
    }

    try:
        mime_type = (
            mimetypes.guess_type(fixture.name)[0]
            or "application/octet-stream"
        )

        form_data = {}

        if engine == "chromium" and wait_delay:
            form_data["waitDelay"] = wait_delay

        with fixture.open("rb") as file_handle:
            files = {
                "files": (
                    fixture.name,
                    file_handle,
                    mime_type,
                )
            }

            response = requests.post(
                url,
                headers={"Gotenberg-Trace": trace_id},
                files=files,
                data=form_data,
                timeout=timeout,
            )

        latency = time.perf_counter() - started
        content = response.content

        valid_pdf = content.startswith(b"%PDF-")

        result.update(
            {
                "status_code": response.status_code,
                "success": (
                    response.status_code == 200
                    and valid_pdf
                ),
                "latency_s": latency,
                "size_bytes": len(content),
                "valid_pdf": valid_pdf,
            }
        )

    except requests.RequestException as exc:
        result["latency_s"] = time.perf_counter() - started
        result["error"] = str(exc)

    except OSError as exc:
        result["latency_s"] = time.perf_counter() - started
        result["error"] = str(exc)

    return result


def run_warmup(args):
    if args.warmup <= 0:
        return

    print(f"Warming {args.engine} with {args.warmup} request(s)...")

    warmup_start = time.perf_counter()

    for request_id in range(1, args.warmup + 1):
        result = perform_request(
            request_id=request_id,
            engine=args.engine,
            target_url=args.target,
            fixture=args.fixture,
            wait_delay=None,
            timeout=args.timeout,
            run_id="warmup",
            benchmark_start=warmup_start,
        )

        if not result["success"]:
            print(
                "Warmup failed:",
                result["status_code"],
                result["error"],
                file=sys.stderr,
            )
            sys.exit(1)


def write_request_csv(results, output_file):
    fields = [
        "request_id",
        "trace_id",
        "start_offset_s",
        "status_code",
        "success",
        "latency_s",
        "size_bytes",
        "valid_pdf",
        "error",
    ]

    with output_file.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)

        writer.writeheader()

        for result in results:
            row = result.copy()

            if row["start_offset_s"] is not None:
                row["start_offset_s"] = (
                    f"{row['start_offset_s']:.6f}"
                )

            if row["latency_s"] is not None:
                row["latency_s"] = (
                    f"{row['latency_s']:.6f}"
                )

            writer.writerow(row)


def build_summary(args, results, wall_time, run_id):
    successful = [
        result
        for result in results
        if result["success"]
    ]

    failed = [
        result
        for result in results
        if not result["success"]
    ]

    latencies = [
        result["latency_s"]
        for result in successful
        if result["latency_s"] is not None
    ]

    def rounded(value):
        if value is None:
            return None
        return round(value, 6)

    return {
        "run_id": run_id,
        "engine": args.engine,
        "target": args.target,
        "fixture": str(args.fixture),
        "request_count": args.request_count,
        "concurrency": args.concurrency,
        "warmup_requests": args.warmup,
        "wait_delay": args.wait_delay,
        "timeout_s": args.timeout,
        "success_count": len(successful),
        "failure_count": len(failed),
        "success_rate_pct": round(
            (len(successful) / len(results)) * 100,
            2,
        ),
        "wall_time_s": rounded(wall_time),
        "throughput_rps": rounded(
            len(successful) / wall_time
            if wall_time > 0
            else 0
        ),
        "latency_successful_s": {
            "min": rounded(min(latencies))
            if latencies else None,
            "p50": rounded(percentile(latencies, 50)),
            "p95": rounded(percentile(latencies, 95)),
            "p99": rounded(percentile(latencies, 99)),
            "max": rounded(max(latencies))
            if latencies else None,
        },
    }


def parse_args():
    parser = argparse.ArgumentParser(
        description="OpsLens Gotenberg workload generator"
    )

    parser.add_argument(
        "--engine",
        choices=["chromium", "libreoffice"],
        required=True,
    )

    parser.add_argument(
        "--target",
        default="http://127.0.0.1:3000",
    )

    parser.add_argument(
        "--fixture",
        type=Path,
        required=True,
    )

    parser.add_argument(
        "--requests",
        dest="request_count",
        type=int,
        default=20,
    )

    parser.add_argument(
        "--concurrency",
        type=int,
        default=1,
    )

    parser.add_argument(
        "--warmup",
        type=int,
        default=1,
    )

    parser.add_argument(
        "--wait-delay",
        default=None,
        help="Chromium waitDelay, for example 2s",
    )

    parser.add_argument(
        "--timeout",
        type=float,
        default=60.0,
    )

    parser.add_argument(
        "--output-dir",
        type=Path,
        required=True,
    )

    return parser.parse_args()


def validate_args(args):
    if not args.fixture.is_file():
        raise SystemExit(
            f"Fixture does not exist: {args.fixture}"
        )

    if args.request_count < 1:
        raise SystemExit("--requests must be >= 1")

    if args.concurrency < 1:
        raise SystemExit("--concurrency must be >= 1")

    if args.concurrency > args.request_count:
        raise SystemExit(
            "--concurrency cannot exceed --requests"
        )

    if args.warmup < 0:
        raise SystemExit("--warmup must be >= 0")

    if (
        args.engine != "chromium"
        and args.wait_delay is not None
    ):
        raise SystemExit(
            "--wait-delay is only valid for Chromium"
        )


def main():
    args = parse_args()
    validate_args(args)

    args.output_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    run_warmup(args)

    run_id = uuid.uuid4().hex[:8]

    print()
    print("Starting OpsLens workload")
    print(f"Run ID:       {run_id}")
    print(f"Engine:       {args.engine}")
    print(f"Requests:     {args.request_count}")
    print(f"Concurrency:  {args.concurrency}")
    print(f"Fixture:      {args.fixture}")

    if args.wait_delay:
        print(f"waitDelay:    {args.wait_delay}")

    print()

    benchmark_start = time.perf_counter()

    results = []

    with ThreadPoolExecutor(
        max_workers=args.concurrency
    ) as executor:

        futures = [
            executor.submit(
                perform_request,
                request_id,
                args.engine,
                args.target,
                args.fixture,
                args.wait_delay,
                args.timeout,
                run_id,
                benchmark_start,
            )
            for request_id in range(
                1,
                args.request_count + 1,
            )
        ]

        for future in as_completed(futures):
            results.append(future.result())

    wall_time = time.perf_counter() - benchmark_start

    results.sort(
        key=lambda result: result["request_id"]
    )

    request_csv = (
        args.output_dir / "requests.csv"
    )

    summary_json = (
        args.output_dir / "summary.json"
    )

    write_request_csv(
        results,
        request_csv,
    )

    summary = build_summary(
        args,
        results,
        wall_time,
        run_id,
    )

    with summary_json.open("w") as handle:
        json.dump(
            summary,
            handle,
            indent=2,
        )

    print(json.dumps(summary, indent=2))

    print()
    print(f"Requests: {request_csv}")
    print(f"Summary:  {summary_json}")

    if summary["failure_count"] > 0:
        sys.exit(2)


if __name__ == "__main__":
    main()
