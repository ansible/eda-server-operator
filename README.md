# EDA Server Operator

# Testing CI :)

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Code of Conduct](https://img.shields.io/badge/code%20of%20conduct-Ansible-yellow.svg)](https://docs.ansible.com/ansible/latest/community/code_of_conduct.html) 

A Kubernetes operator for Kubernetes built with [Operator SDK](https://github.com/operator-framework/operator-sdk) and Ansible for deploying and maintaining the lifecycle of your [EDA Server](https://github.com/ansible/eda-server) application.

## Overview

This operator is meant to provide a more Kubernetes-native installation method for EDA Server via an EDA Custom Resource Definition (CRD). In the future, this operator will grow to be able to maintain the full life-cycle of an EDA Server deployment. Currently, it can handle fresh installs and upgrades.

## Contributing

Please visit [our contributing guide](https://github.com/ansible/eda-server-operator/blob/devel/CONTRIBUTING.md) which has details about how to set up your development environment.

### Prerequisites

* Install the kubernetes-based cluster of your choice:
  * [Openshift](https://docs.openshift.com/container-platform/4.11/installing/index.html)
  * [K8s](https://kubernetes.io/docs/setup/)
  * [CodeReady containers](https://access.redhat.com/documentation/en-us/red_hat_openshift_local/2.5)
  * [minikube](https://minikube.sigs.k8s.io/docs/start/)
* Deploy AWX using the [awx-operator](https://github.com/ansible/awx-operator#basic-install)
* [Create an OAuth2 token](./docs/create-awx-token.md) for your user in the AWX UI

## Install the EDA Server Operator

Before you begin, you need to have a k8s cluster up. If you don't already have a k8s cluster, you can use minikube to start a lightweight k8s cluster locally by following these [minikube test cluster docs](./docs/minikube-test-cluster.md).

Once you have a running Kubernetes cluster, you can deploy EDA Server Operator into your cluster using [Kustomize](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/). Since kubectl version 1.14 kustomize functionality is built-in (otherwise, follow the instructions here to install the latest version of Kustomize: https://kubectl.docs.kubernetes.io/installation/kustomize/)

First, create a file called `kustomization.yaml` with the following content:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - config/default

# Set the image tags to match the git version from above
images:
  - name: quay.io/ansible/eda-server-operator
    newTag: 0.0.1

# Specify a custom namespace in which to install EDA
namespace: eda
```

You can use kustomize directly to dynamically modify things like the operator deployment at deploy time.  For more info, see the [kustomize install docs](./docs/kustomize-install.md).



Install the manifests by running this:

```bash
$ kubectl apply -k .
```

Check that your operator pod is running, this may take about a minute.

```bash
$ kubectl get pods
```

## Deploy EDA

EDA is designed to be used alongside the [AWX project](https://github.com/ansible/awx) to trigger automation jobs in AWX. There is some configuration that needs to be done in AWX first so that EDA can  AWX.

1. Create an access token in your AWX instance using [these docs](./docs/create-awx-token.md).

2. Now that your operator pod is up and running, you can create an EDA Server resource by applying the following YAML:

> **Warning**
> At the moment, If you are using custom image eda-server and eda-ui images that are in a private registry, you will need to [create and configure a pull secret](#configuring-an-image-pull-secret).

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

If you are using Openshift, you can take advantage of automatic Route configuration an EDA custom resource like this:

```yaml
apiVersion: eda.ansible.com/v1alpha1
kind: EDA
metadata:
  name: eda-demo
spec:
  automation_server_url: https://awx-host
  service_type: ClusterIP
  ingress_type: Route
  image_pull_secrets:
    - pull_secret_name
```


### Advanced Configuration

#### Deploying a specific version of EDA

There are a few variables that are customizable for eda the image management.

| Name                   | Description               | Default                                 |
| ---------------------- | ------------------------- | --------------------------------------  |
| image                  | Path of the image to pull | quay.io/ansible/eda-server              |
| image_version          | Image version to pull     | main                                    |
| image                  | Path of the image to pull | quay.io/ansible/eda-ui                  |
| image_version          | Image version to pull     | latest                                  |
| image_pull_policy      | The pull policy to adopt  | IfNotPresent                            |
| image_pull_secrets     | The pull secrets to use   | None                                    |
| redis_image            | Path of the image to pull | redis                                   |
| redis_image_version    | Image version to pull     | latest                                  |
| postgres_image         | Path of the image to pull | postgres                                |
| postgres_image_version | Image version to pull     | latest                                  |

Example of customization could be:

```yaml
---
spec:
  ...
  image: myorg/my-custom-eda
  image_version: latest
  image_web: myorg/my-custom-eda
  image_web_version: latest
  image_pull_policy: Always
  image_pull_secrets:
    - pull_secret_name
```

  > **Note**: The `*_image` and `*_image_version` variables are intended for local mirroring scenarios. Please note that using a version of EDA other than the one bundled with the `eda-server-operator` is **not** supported. For the default values, check the [main.yml](https://github.com/ansible/eda-server-operator/blob/main/roles/eda/defaults/main.yml) file.


#### Configuring an image pull secret

1. Log in with that token, or username/password, then create a pull secret from the docker/config.json

```bash
docker login quay.io -u <user> -p <token>
```

2. Then, create a k8s secret from your .docker/config.json file. This pull secret should be created in the same namespace you are installing the EDA Operator.

```bash
kubectl create secret generic redhat-operators-pull-secret \
  --from-file=.dockerconfigjson=.docker/config.json \
  --type=kubernetes.io/dockerconfigjson
```

3. Add that image pull secret to your EDA spec

```yaml
---
spec:
  image_pull_secrets:
    - redhat-operators-pull-secret
```
