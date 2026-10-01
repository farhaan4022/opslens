# ADR-0001: Use an existing production workload instead of building a demo application

## Status

Accepted

## Context

The objective of OpsLens is to demonstrate SRE and platform engineering,
not application-development complexity.

A custom application would consume engineering time while providing an
artificial workload whose operational behaviour was created specifically
for the project.

## Decision

Use Gotenberg as the primary workload.

Gotenberg provides real Chromium and LibreOffice document-processing
behaviour, resource-intensive subprocesses, queueing characteristics,
health endpoints and telemetry that can be evaluated under controlled load.

## Consequences

The project will not claim ownership of Gotenberg application code.

Original work will focus on infrastructure, workload characterization,
observability, reliability controls, scaling, fault experiments,
automation and measurable operational improvements.
