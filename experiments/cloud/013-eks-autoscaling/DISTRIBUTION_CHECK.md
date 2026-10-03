# Two-Replica Load Distribution Check

Before testing queue-aware scaling, both engine Deployments were forced to
two Ready replicas before workload generation.

EndpointSlice inspection confirmed two Ready endpoints for each Service.

Observed mean CPU:

- Chromium replica 1: 517.4m
- Chromium replica 2: 454.9m
- LibreOffice replica 1: 474.3m
- LibreOffice replica 2: 315.3m

Observed peak CPU:

- Chromium replicas: 995m and 986m
- LibreOffice replicas: 806m and 787m

Both replicas therefore received meaningful work when they were Ready before
the burst.

The imbalance observed during Experiment 013A is therefore more consistent
with late scale-out and workload/connection timing than with an inability of
the Service path to use newly available endpoints.

No routing redesign is introduced before Experiment 013B.
