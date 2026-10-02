import json
from pathlib import Path

ecs = Path("experiments/cloud/009-ecs-single-task-baseline/formal")
eks = Path("experiments/cloud/011-eks-single-pod-baseline/formal")

print(
    f"{'ENGINE':<13} {'C':>3} "
    f"{'ECS RPS':>8} {'EKS RPS':>8} {'RPS Δ':>8} "
    f"{'ECS P95':>8} {'EKS P95':>8} {'P95 Δ':>8}"
)
print("-" * 82)

for engine in ("chromium", "libreoffice"):
    for c in (1, 2, 4, 6, 8, 12):
        e = json.loads((ecs / engine / f"c{c}" / "summary.json").read_text())
        k = json.loads((eks / engine / f"c{c}" / "summary.json").read_text())

        erps = e["throughput_rps"]
        krps = k["throughput_rps"]

        ep95 = e["latency_successful_s"]["p95"]
        kp95 = k["latency_successful_s"]["p95"]

        rps_delta = (krps / erps - 1) * 100
        p95_delta = (kp95 / ep95 - 1) * 100

        print(
            f"{engine:<13} {c:>3} "
            f"{erps:>8.3f} {krps:>8.3f} {rps_delta:>+7.1f}% "
            f"{ep95:>8.3f} {kp95:>8.3f} {p95_delta:>+7.1f}%"
        )

    print()
