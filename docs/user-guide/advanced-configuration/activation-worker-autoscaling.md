# Activation Worker Autoscaling

An opt-in Kubernetes HorizontalPodAutoscaler (HPA) scales the
`<eda-name>-activation-worker` Deployment. It scales dispatcherd
`ActivationWorker` management processes, **not individual rulebook execution
Jobs or the event-processing capacity of an existing activation**.

## Configuration

```yaml
spec:
  activation_worker:
    replicas: 2  # Used only when autoscaling is disabled
    resource_requirements:
      requests:
        cpu: 25m
        memory: 150Mi
    autoscaling:
      enabled: true
      min_replicas: 2
      max_replicas: 6
      target_cpu_utilization_percentage: 70
```

| Field | Default | Requirement |
| --- | --- | --- |
| `enabled` | `false` | Boolean; fixed replicas remain the default |
| `min_replicas` | `2` | Integer >= 1 |
| `max_replicas` | `6` | Integer >= min_replicas |
| `target_cpu_utilization_percentage` | `70` | Positive integer |

The operator validates the relationship between bounds and requires a positive
CPU request while autoscaling is enabled. Targets are percentages of **requests**,
not CPU limits; values above 100 are allowed. Legacy `worker` settings remain
supported, with explicit `activation_worker` settings taking precedence.

These values are illustrative, not production sizing recommendations. With the
current 25m CPU request, 70% corresponds to approximately 17.5m average CPU per
worker. Benchmark requests and targets together. CPU must correlate with worker
demand; waiting on Jobs or database operations may make backlog metrics a better
future scaling signal.

## Prerequisites and behavior

The cluster must serve CPU metrics through `metrics.k8s.io` (Metrics Server or
an equivalent provider). Check with `kubectl top pods -n <namespace>`.
The operator manages an `autoscaling/v2` HPA named
`<eda-name>-activation-worker` in the EDA namespace. It targets the same-named
`apps/v1` Deployment with a CPU Resource/Utilization metric and a 300-second
scale-down stabilization window. HPA tolerance, metric availability, readiness,
and stabilization affect when replica changes occur; thresholds are not
instantaneous scale commands.

When enabled, the operator releases `spec.replicas` from its previous
client-side apply bookkeeping while preserving the live replica count. Subsequent
reconciliation omits replicas so HPA can control them. Fresh installations and
existing zero-replica Deployments bootstrap at `min_replicas`. Existing nonzero
Deployments remain at their current count until HPA reconciles its bounds.

To return to fixed replicas, set `autoscaling.enabled: false` and configure
`activation_worker.replicas`. The operator removes the HPA before restoring that
count. With autoscaling disabled, setting replicas to zero is also supported.

For whole-installation idle mode, use `spec.idle_deployment: true`. The operator
removes the HPA before scaling down. Set `idle_deployment: false` to resume;
when autoscaling is enabled, the operator bootstraps nonzero worker capacity
before recreating the HPA. A positive-minimum HPA alone does not normally
reactivate a Deployment held at zero.

## Troubleshooting and production validation

Inspect `kubectl describe hpa <eda-name>-activation-worker -n <namespace>` and
its events. `AbleToScale` reports scaling access/readiness, `ScalingActive`
reports metric-based scaling availability, and `ScalingLimited` indicates that
bounds constrain a recommendation. For missing metrics, check the cluster
metrics provider, pod readiness, and CPU requests on all regular containers,
including injected sidecars. The operator does not install a metrics provider.

This implementation supports CPU scaling only. It does not establish dispatcherd
graceful-termination safety or CPU's effectiveness as a capacity signal. Before
production use, run workload tests covering scale-up, stabilized scale-down,
in-flight work, activation Job survival, and absence of duplicate execution or
orphaned activations. Lifecycle integration tests must also verify replica
ownership handoff and idle/resume on the supported cluster and collection
versions. Keep the change in draft until these gates have evidence.

See [Kubernetes HPA documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/).
