#!/usr/bin/env python3

rows = [
    ("Chromium scale decision", "36.609 s", "2.548 s", "34.061 s earlier"),
    ("LibreOffice scale decision", "36.609 s", "2.571 s", "34.038 s earlier"),
    ("Chromium pod Ready", "55.148 s", "5.300 s", "49.848 s earlier"),
    ("LibreOffice pod Ready", "55.148 s", "5.300 s", "49.848 s earlier"),
    ("Chromium throughput", "3.905 RPS", "3.811 RPS", "-2.4%"),
    ("Chromium p95", "3.978 s", "4.118 s", "+3.5%"),
    ("LibreOffice throughput", "4.305 RPS", "6.021 RPS", "+39.9%"),
    ("LibreOffice p95", "3.424 s", "3.336 s", "-2.6%"),
    ("Overall burst", "154.972 s", "158.165 s", "+2.1%"),
]

print()
print("EXPERIMENT 013 — AUTOSCALING COMPARISON")
print("=" * 91)
print(
    f"{'Measurement':<31}"
    f"{'CPU HPA':>17}"
    f"{'Queue-aware':>18}"
    f"{'Difference':>25}"
)
print("-" * 91)

for metric, cpu, queue, diff in rows:
    print(
        f"{metric:<31}"
        f"{cpu:>17}"
        f"{queue:>18}"
        f"{diff:>25}"
    )

print("-" * 91)
print("Scale-decision latency reduction: ~93%")
print("Failures: CPU HPA = 0 | Queue-aware = 0")
print()
