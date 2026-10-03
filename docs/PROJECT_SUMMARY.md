# OpsLens Project Summary

## One-line version

Built a measurement-driven SRE lab around Gotenberg on AWS/EKS, progressing from workload characterization through autoscaling, observability, failure injection, durable-result validation, GitOps, and measured availability hardening.

## Two-minute project story

OpsLens started by characterizing Gotenberg rather than immediately deploying a complex platform. Chromium and LibreOffice showed different throughput, CPU, memory, and interference behavior. I established local baselines, then moved the same workload to ECS and EKS so I could compare scaling and operational behavior without changing the application itself.

The mixed-workload experiments showed that the engines interfered with one another, so I split them into independent Kubernetes Deployments behind Envoy. I then compared normal CPU HPA with a queue-aware scaler. The queue signal reacted far earlier, but the experiment also showed that faster scaling decisions do not automatically improve end-to-end performance when another bottleneck dominates.

For observability I kept the scope bounded: Prometheus for metrics, Grafana for visualization, Loki for persistent logs, OpenTelemetry Collector for log collection, and CloudWatch for AWS/EKS infrastructure. I added reliability-oriented recording and alert rules, including correct idle-traffic semantics.

Next I injected real failures. Deleting the single Envoy gateway caused four failures in a 90-request run. That gave me a concrete production-hardening target. I changed the gateway to two replicas with anti-affinity and a PodDisruptionBudget, deployed the change through Argo CD, and repeated the same failure class. The hardened run completed 90/90 requests successfully.

The project also validates real PDF durability through an encrypted, versioned S3 bucket and validates asynchronous Gotenberg webhooks. GitHub Actions validates repository changes while Argo CD owns the active application boundary.

The main lesson is that I did not add tools for their own sake: each architecture change came from a measured behavior, failure, or ownership requirement.
