# Assigning EDA pods to specific nodes

You can constrain the EDA pods created by the operator to run on a certain subset of nodes. `node_selector` and `tolerations` contrain the EDA pods to run only on the nodes that match the specified key/value pairs. 

Each component of EDA has its own `node_selector` and `tolerations` values. The supported components are `ui`, `api`, `default_worker`, `activation_worker`, `worker`, `scheduler`, `redis` and `database`.

| Name | Description | Type | Default |
|---|---|---|---|
| node_selector  | Pods' nodeSelector.  | `dictionary`  | `{}`  |
| tolerations  | Pods' tolerations  | `list`  | `[]`  |

## Example

```
---
spec:
  ...
  ui:
    node_selector:
      system/dedicated: ui-node-group
    tolerations:
      - key: "system/dedicated"
        operator: "Equal"
        value: "ui-node-group"
        effect: "NoSchedule"
      - key: "application/type"
        operator: "Equal"
        value: "frontend"
        effect: "NoSchedule"
  api:
    node_selector:
      system/dedicated: api-node-group
    tolerations:
      - key: "system/dedicated"
        operator: "Equal"
        value: "api-node-group"
        effect: "NoSchedule"
  default_worker:
    node_selector:
      system/dedicated: worker-node-group
    tolerations:
      - key: "system/dedicated"
        operator: "Equal"
        value: "worker-node-group"
        effect: "NoSchedule"
  database:
    node_selector:
      system/dedicated: database-node-group
    tolerations:
      - key: "system/dedicated"
        operator: "Equal"
        value: "database-node-group"
        effect: "NoSchedule"
  ...
  ```

  For more information about how node selectors and tolerations work, refer to Kubernetes docs on [nodeSelector](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) and [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/).