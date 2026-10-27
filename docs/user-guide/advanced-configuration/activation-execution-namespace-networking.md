# Network prerequisites for activation Jobs in a separate namespace

Activation Jobs can run in an execution namespace separate from the EDA control
plane. The execution namespace **must be dedicated to EDA activations and
administrator-controlled**: only trusted administrators and the authorized EDA
worker should be able to create or label Pods there. The `app: eda` Pod label
used below is a NetworkPolicy selector, **not workload identity**. It is not
a sufficient security boundary in a shared or untrusted namespace.

Administrators own the cross-namespace NetworkPolicy and its lifecycle. Neither
EDA Server Operator nor AAP Gateway Operator creates, updates, or deletes
NetworkPolicies **for cross-namespace activation connectivity**. This does not
change the EDA operator's existing policies for its own namespace. The
execution namespace, its RBAC, ServiceAccounts, Secrets, image-pull access,
quotas, and any execution-namespace NetworkPolicies are also administrator
prerequisites, not resources provisioned by this procedure.

## Configure the execution namespace

Provision the dedicated namespace and the other execution prerequisites before
enabling it. Apply the ingress policy and arrange the DNS and egress access
described below before starting Jobs there. Set the EDA application setting
through the EDA custom resource
(`extra_settings` is also passed through by AAP Gateway Operator):

```yaml
spec:
  extra_settings:
    - setting: EDA_CONTAINER_GROUP_DEFAULT_NAMESPACE
      value: eda-activations
```

Replace `eda-activations` with your execution namespace. The activation worker
uses this setting for new Jobs; it must be able to manage Jobs and the related
resources in that namespace. When changing the namespace, retain the access
needed to inspect and clean up Jobs already running in the previous namespace.
Do not assume that changing this setting moves existing Jobs.

The EDA operator configures the following namespace-qualified internal Service
endpoints for activation-to-control-plane traffic (substitute your EDA resource
name and control-plane namespace):

| Destination | Endpoint | Purpose |
| --- | --- | --- |
| Daphne | `ws://<eda-name>-daphne.<control-plane-namespace>.svc:8001` | Rulebook WebSocket |
| EDA API | `http://<eda-name>-api.<control-plane-namespace>.svc:8000` | WebSocket token refresh |

The `.svc` names use the cluster's Pod DNS search configuration and do not
assume a particular cluster DNS domain. Short, unqualified Service names would
resolve in the **execution** namespace and might fail or reach a different
Service there. Ensure activation Pods can resolve both names.

## Allow ingress to the EDA API Pod

Apply the following **additional administrator-owned** NetworkPolicy in the
*control-plane* namespace. Replace all angle-bracketed values. The EDA API
and Daphne Services both select the EDA API Pod; the policy admits only
`app: eda` Pods from the specified execution namespace, on TCP 8000 and 8001.
It does not open PostgreSQL.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: eda-activation-control-plane-ingress
  namespace: <control-plane-namespace>
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: <eda-name>
      app.kubernetes.io/managed-by: eda-operator
      app.kubernetes.io/component: eda-api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: <execution-namespace>
          podSelector:
            matchLabels:
              app: eda
      ports:
        - protocol: TCP
          port: 8000
        - protocol: TCP
          port: 8001
```

The `namespaceSelector` and `podSelector` in the **same** `from` item are
combined: both must match. Check that the execution namespace has the
`kubernetes.io/metadata.name` label. NetworkPolicies are additive; other
policies selecting the API Pod may permit additional traffic. This example is
not a replacement for the existing operator-managed policies, nor is it a
workload-authentication mechanism.

## Allow DNS and egress from the execution namespace

If administrator-managed policies restrict egress from activation Pods in the
execution namespace, explicitly allow:

- DNS to the cluster's actual DNS endpoints, using UDP and TCP port 53 (and
  any other ports required by the cluster DNS deployment). On OpenShift, check
  the DNS implementation and existing namespace policies rather than assuming
  a particular DNS Pod selector.
- TCP to the EDA API Service on 8000 and the Daphne Service on 8001 in the
  control-plane namespace. Account for how your cluster enforces policies on
  traffic to Services and their backing Pods.
- Any destinations needed by the chosen rulebook's event sources and actions.

### PostgreSQL-backed event sources

The WebSocket and token-refresh path does **not** require activation Pods to
connect to PostgreSQL. Some event sources, such as `ansible.eda.pg_listener`,
connect directly from the activation Pod to the database; database-backed
rulebooks or persistence may have similar requirements. These connections do
not go through the EDA API or Daphne Services.

For the operator-managed PostgreSQL database, the Service endpoint is
`<eda-name>-postgres-<pg-version>.<control-plane-namespace>.svc` on TCP 5432
(for example, `eda-demo-postgres-15.eda.svc:5432`). Use the actual database
host and port configured for the event source if they differ, particularly
when using an external database.

For a PostgreSQL-backed event source in a separate execution namespace, allow
both of these paths:

1. Egress from activation Pods to the database Pods on the configured
   PostgreSQL TCP port. If execution-namespace egress is restricted, add this
   narrow allowance while retaining the DNS allowance above.
2. Ingress to the database Pods from `app: eda` Pods in the execution
   namespace. The operator-generated PostgreSQL NetworkPolicy allows `app: eda`
   Pods from its **own namespace**; its `podSelector` has no `namespaceSelector`,
   so it does not grant access to activation Pods in another namespace.

The following are additional, administrator-owned policies for an
operator-managed PostgreSQL database. They use the PostgreSQL Pod labels
generated by the operator; replace the placeholders and port with the values
for your deployment. The namespace and Pod selectors in each `to` or `from`
item are combined, so both must match. Keep the existing operator-managed
policies in place.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: eda-activation-postgres-egress
  namespace: <execution-namespace>
spec:
  podSelector:
    matchLabels:
      app: eda
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: <control-plane-namespace>
          podSelector:
            matchLabels:
              app.kubernetes.io/name: postgres-<pg-version>
              app.kubernetes.io/instance: postgres-<pg-version>-<eda-name>
              app.kubernetes.io/component: database
      ports:
        - protocol: TCP
          port: 5432
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: eda-activation-postgres-ingress
  namespace: <control-plane-namespace>
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: postgres-<pg-version>
      app.kubernetes.io/instance: postgres-<pg-version>-<eda-name>
      app.kubernetes.io/component: database
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: <execution-namespace>
          podSelector:
            matchLabels:
              app: eda
      ports:
        - protocol: TCP
          port: 5432
```

These examples apply to the operator-managed database. For an external
database, allow the configured destination and port using the applicable
execution-namespace egress policy and external firewall or database controls;
there is no in-cluster PostgreSQL Pod NetworkPolicy to update. Do not expect a
PostgreSQL-backed event source to work when either required network path is
denied.

## Validate on an enforced-policy OpenShift cluster

1. Confirm the dedicated execution namespace and its administrator-provided
   prerequisites are ready. Verify the cluster enforces NetworkPolicies and
   check the actual DNS and egress restrictions in the execution namespace.
2. Apply the completed ingress policy in the control-plane namespace (for
   example, `oc apply -f eda-activation-control-plane-ingress.yaml`). Confirm
   its Pod selector matches the EDA API Pod and its namespace selector matches
   the execution namespace; leave the existing operator policies in place.
3. Verify the EDA environment ConfigMap contains both namespace-qualified
   Service URLs. Start a non-event-stream activation that does not require
   database access. Confirm its `app: eda` Job Pod runs in the execution
   namespace and resolves the two control-plane Service names.
4. Inspect the activation and its logs to confirm it connects to Daphne and
   can refresh its token through the EDA API. Exercise token refresh with a
   sufficiently long-running activation rather than inferring it from the
   initial WebSocket connection alone. If connectivity fails, check DNS,
   execution-namespace egress, this policy's selectors and ports, and any
   other policies selecting the API Pod.

For example, inspect the policy and the running activation with:

```bash
oc get networkpolicy -n <control-plane-namespace> eda-activation-control-plane-ingress -o yaml
oc get jobs,pods -n <execution-namespace> -l app=eda
oc logs -n <execution-namespace> job/<activation-job-name>
```

Check DNS resolution from the activation Pod using the tools available in its
decision-environment image.

This validation requires a real cluster with enforced policies: rendering or
applying the policy alone does not demonstrate that an activation can connect.
