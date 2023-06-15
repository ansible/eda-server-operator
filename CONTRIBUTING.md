# Contributing


## Development Environment

There are a couple ways to make and test changes to an Ansible operator. The easiest way is to build and deploy the operator from your branch using the make targets. This is closed to how the operator will be used, and is what is documented below. However, it may be useful to run the EDA Operator roles directly on your local machine for faster iteration. This involves a bit more set up, and is described in the [Debugging docs](./docs/debugging.md).

First, you need to have a k8s cluster up. If you don't already have a k8s cluster, you can use minikube to start a lightweight k8s cluster locally by following these [minikube test cluster docs](./docs/minikube-test-cluster.md).



### Build Operator Image

Clone the eda-server-operator

```
git clone git@github.com:ansible/eda-server-operator.git
```

Create an image repo in your user called `eda-server-operator` on [quay.io](https://quay.io) or your preferred image registry. 

Build & push the operator image

```
export QUAY_USER=username
export TAG=feature-branch
make docker-build docker-push IMG=quay.io/$QUAY_USER/eda-server-operator:$TAG
```


### Deploy EDA Operator


1. Log in to your K8s or Openshift cluster.

```
kubectl login <cluster-url>
```

2. Run the `make deploy` target

```
NAMESPACE=eda IMG=quay.io/$QUAY_USER/eda-server-operator:$TAG make deploy
```
> **Note** The `latest` tag on the quay.io/ansible/eda-server-operator repo is the latest _released_ (tagged) version and the `main` tag is built from the HEAD of the `main` branch. To deploy with the latest code in `main` branch, check out the main branch, and use `IMG=quay.io/ansible/eda-server-operator:main` instead.


### Create an EDA CR

Create a yaml file defining the EDA custom resource

```yaml
# eda.yaml
apiVersion: eda.ansible.com/v1alpha1
kind: EDA
metadata:
  name: my-eda
spec:
  automation_server_url: https://awx-host
```

3. Now apply this yaml

```bash
$ kubectl apply -f eda.yaml
```
