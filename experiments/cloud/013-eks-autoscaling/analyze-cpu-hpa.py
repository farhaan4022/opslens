#!/usr/bin/env python3

from pathlib import Path
import csv
import json

BASE = Path(
    "experiments/cloud/013-eks-autoscaling/results/cpu-hpa"
)

burst_start = int((BASE / "burst-start-ms.txt").read_text().strip())
burst_end = int((BASE / "burst-end-ms.txt").read_text().strip())

def rel(ts):
    return (int(ts) - burst_start) / 1000.0

print("=" * 72)
print("EXPERIMENT 013A — CPU HPA ANALYSIS")
print("=" * 72)

print(f"\nBurst duration: {(burst_end - burst_start)/1000:.3f}s")


# ---------------------------------------------------------
# Workload summaries
# ---------------------------------------------------------

print("\nWORKLOAD RESULTS")
print("-" * 72)

for engine in ("chromium", "libreoffice"):
    p = BASE / engine / "summary.json"
    d = json.loads(p.read_text())
    lat = d["latency_successful_s"]

    print(
        f"{engine:<12} "
        f"ok={d['success_count']:<3} "
        f"fail={d['failure_count']:<3} "
        f"rps={d['throughput_rps']:.3f} "
        f"p50={lat['p50']:.3f}s "
        f"p95={lat['p95']:.3f}s "
        f"p99={lat['p99']:.3f}s"
    )


# ---------------------------------------------------------
# HPA timeline
# ---------------------------------------------------------

print("\nHPA TIMELINE")
print("-" * 72)

hpa_rows = []

with (BASE / "hpa.tsv").open() as f:
    reader = csv.DictReader(f, delimiter="\t")
    hpa_rows = list(reader)

for hpa in ("gotenberg-chromium", "gotenberg-libreoffice"):

    rows = [r for r in hpa_rows if r["hpa"] == hpa]

    valid_cpu = []
    scale2 = []

    for r in rows:
        try:
            cpu = int(r["cpu_pct"])
            valid_cpu.append((int(r["timestamp_ms"]), cpu))
        except (ValueError, TypeError):
            pass

        try:
            if int(r["desired_replicas"]) >= 2:
                scale2.append(r)
        except (ValueError, TypeError):
            pass

    over_target = [
        (ts, cpu)
        for ts, cpu in valid_cpu
        if cpu >= 70
    ]

    peak_cpu = max(
        (cpu for _, cpu in valid_cpu),
        default=None
    )

    print(f"\n{hpa}")

    if peak_cpu is not None:
        print(f"  peak observed CPU: {peak_cpu}%")

    if over_target:
        ts, cpu = over_target[0]
        print(
            f"  first CPU >=70%:   "
            f"{rel(ts):+.3f}s after burst start "
            f"({cpu}%)"
        )
    else:
        print("  first CPU >=70%:   not observed")

    if scale2:
        r = scale2[0]
        print(
            f"  desired replicas=2:"
            f" {rel(r['timestamp_ms']):+.3f}s after burst start"
        )
    else:
        print("  desired replicas=2: not observed")


# ---------------------------------------------------------
# Deployment scaling
# ---------------------------------------------------------

print("\nDEPLOYMENT TIMELINE")
print("-" * 72)

with (BASE / "deployments.tsv").open() as f:
    dep_rows = list(csv.DictReader(f, delimiter="\t"))

for dep in ("gotenberg-chromium", "gotenberg-libreoffice"):

    rows = [r for r in dep_rows if r["deployment"] == dep]

    spec2 = []
    ready2 = []
    avail2 = []

    for r in rows:
        try:
            if int(r["spec_replicas"]) >= 2:
                spec2.append(r)
            if int(r["ready"]) >= 2:
                ready2.append(r)
            if int(r["available"]) >= 2:
                avail2.append(r)
        except (ValueError, TypeError):
            pass

    print(f"\n{dep}")

    if spec2:
        print(
            f"  deployment spec=2: "
            f"{rel(spec2[0]['timestamp_ms']):+.3f}s"
        )
    else:
        print("  deployment spec=2: not observed")

    if ready2:
        print(
            f"  ready replicas=2:  "
            f"{rel(ready2[0]['timestamp_ms']):+.3f}s"
        )
    else:
        print("  ready replicas=2:  not observed")

    if avail2:
        print(
            f"  available=2:       "
            f"{rel(avail2[0]['timestamp_ms']):+.3f}s"
        )
    else:
        print("  available=2:       not observed")


# ---------------------------------------------------------
# Pod lifecycle
# ---------------------------------------------------------

print("\nPOD LIFECYCLE")
print("-" * 72)

with (BASE / "pods.tsv").open() as f:
    pod_rows = list(csv.DictReader(f, delimiter="\t"))

pods = {}

for r in pod_rows:
    pods.setdefault(r["pod"], []).append(r)

for pod, rows in sorted(pods.items()):

    first_seen = min(rows, key=lambda x: int(x["timestamp_ms"]))

    ready_rows = [
        r for r in rows
        if str(r["ready"]).lower() == "true"
    ]

    first_ready = (
        min(ready_rows, key=lambda x: int(x["timestamp_ms"]))
        if ready_rows else None
    )

    print(f"\n{pod}")
    print(
        f"  first observed: "
        f"{rel(first_seen['timestamp_ms']):+.3f}s"
    )
    print(f"  node:           {first_seen['node']}")

    if first_ready:
        print(
            f"  first Ready:     "
            f"{rel(first_ready['timestamp_ms']):+.3f}s"
        )


# ---------------------------------------------------------
# Resource peaks
# ---------------------------------------------------------

print("\nRESOURCE PEAKS")
print("-" * 72)

def cpu_to_m(v):
    if v.endswith("m"):
        return int(v[:-1])
    return int(float(v) * 1000)

def mem_to_mi(v):
    if v.endswith("Mi"):
        return float(v[:-2])
    if v.endswith("Gi"):
        return float(v[:-2]) * 1024
    if v.endswith("Ki"):
        return float(v[:-2]) / 1024
    return float(v)

with (BASE / "pod-resources.tsv").open() as f:
    resource_rows = list(csv.DictReader(f, delimiter="\t"))

resource_pods = {}

for r in resource_rows:
    resource_pods.setdefault(r["pod"], []).append(r)

for pod, rows in sorted(resource_pods.items()):

    cpus = []
    mems = []

    for r in rows:
        try:
            cpus.append(cpu_to_m(r["cpu"]))
        except Exception:
            pass

        try:
            mems.append(mem_to_mi(r["memory"]))
        except Exception:
            pass

    if not cpus and not mems:
        continue

    print(
        f"{pod:<48} "
        f"peak_cpu={max(cpus) if cpus else 'NA'}m "
        f"peak_mem={max(mems) if mems else 'NA'}Mi"
    )


# ---------------------------------------------------------
# Generic queue file analysis
# ---------------------------------------------------------

print("\nQUEUE PEAKS")
print("-" * 72)

for filename in (
    "chromium-queues.tsv",
    "libreoffice-queues.tsv",
):

    path = BASE / filename

    print(f"\n{filename}")

    if not path.exists():
        print("  missing")
        continue

    with path.open() as f:
        reader = csv.DictReader(f, delimiter="\t")
        rows = list(reader)

    if not rows:
        print("  no samples")
        continue

    columns = reader.fieldnames or []

    for col in columns:

        if "time" in col.lower():
            continue

        nums = []

        for r in rows:
            try:
                nums.append(float(r[col]))
            except (ValueError, TypeError, KeyError):
                pass

        if nums:
            print(f"  {col}: peak={max(nums):g}")


print("\n" + "=" * 72)
print("END")
print("=" * 72)
