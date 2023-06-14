# Debugging the EDA Operator

## General Debugging

When the operator is deploying EDA, it is running the `eda` role inside the operator container. If the EDA CR's status is `Failed`, it is often useful to look at the eda-server-operator container logs, which shows the output of the installer role. To see these logs, run:

```
kubectl logs deployments/eda-server-operator-controller-manager -c eda-server-manager -f
```

### Inspect k8s Resources

Past that, it is often useful to inspect various resources the EDA Operator manages like:
* eda
* edabackup
* edarestore
* pod
* deployment
* statefulset
* pvc
* service
* ingress
* route
* secrets
* serviceaccount

And if installing via OperatorHub and OLM:
* subscription
* csv
* installPlan
* catalogSource

To inspect these resources you can use these commands

```
# Inspecting k8s resources
kubectl describe -n <namespace> <resource> <resource-name>
kubectl get -n <namespace> <resource> <resource-name> -o yaml
kubectl logs -n <namespace> <resource> <resource-name>

# Inspecting Pods
kubectl exec -it -n <namespace> <pod> <pod-name>
```


### Configure No Log

It is possible to show task output for debugging by setting no_log to false on the EDA CR spec.
This will show output in the eda-server-operator logs for any failed tasks where no_log was set to true.

For example:

```yaml
apiVersion: eda.ansible.com/v1alpha1
kind: EDA
metadata:
  name: my-eda
spec:
  automation_server_url: https://awx-host
  no_log: false                  # <------------
```

## Iterating on the installer without deploying the operator

Go through the [normal basic install](https://github.com/ansible/eda-server-operator/blob/devel/README.md#install-the-eda-server-operator) steps.

Install some dependencies:

```
$ ansible-galaxy collection install -r molecule/requirements.yml
$ pip install -r molecule/requirements.txt
```

To prevent the changes we're about to make from being overwritten, scale down any running instance of the operator:

```
$ kubectl scale deployment eda-server-operator-controller-manager --replicas=0
```

Create a playbook that invokes the installer role (the operator uses ansible-runner's role execution feature):

```yaml
# run.yml
---
- hosts: localhost
  vars:
    automation_server_url: https://awx-host.com/
    automation_server_ssl_verify: 'no'
    service_type: ClusterIP
    ingress_type: Route

    no_log: false
    ansible_operator_meta:
      name: eda
      namespace: eda
    set_self_labels: false
      #image: quay.io/username/eda-server
      #image_version: feature-branch
      #image_web: quay.io/username/eda-ui
      #image_web_version: feature-branch
    api:
      replicas: 1
      resource_requirements:
        requests:
          cpu: 200m
          memory: 512Mi
    worker:
      replicas: 1
      resource_requirements:
        requests:
          cpu: 200m
          memory: 512Mi
    ui:
      replicas: 1
      resource_requirements:
        requests:
          cpu: 200m
          memory: 512Mi
    image_pull_policy: Always

  tasks:
    - include_role:
        name: eda
```


Run the installer:

```
$ ansible-playbook run.yml -e @vars.yml -v
```

Grab the URL and admin password:

```
$ minikube service eda-ui --url -n eda
$ minikube kubectl get secret eda-admin-password -- -o jsonpath="{.data.password}" | base64 --decode
LU6lTfvnkjUvDwL240kXKy1sNhjakZmT
```
