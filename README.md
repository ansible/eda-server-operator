# EDA Server Operator

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Code of Conduct](https://img.shields.io/badge/code%20of%20conduct-Ansible-yellow.svg)](https://docs.ansible.com/ansible/latest/community/code_of_conduct.html) 

An [EDA Server](https://github.com/ansible/eda-server) operator for Kubernetes built with [Operator SDK](https://github.com/operator-framework/operator-sdk) and Ansible.

## Overview

This operator is meant to provide a more Kubernetes-native installation method for EDA Server via an EDA Custom Resource Definition (CRD). In the future, this operator will grow to be able to maintain the full life-cycle of an EDA Server deployment. Currently, it can handle fresh installs and upgrades.

### Prerequisites

* Install the kubernetes-based cluster of your choice:
  * [Openshift](https://docs.openshift.com/container-platform/4.11/installing/index.html)
  * [K8s](https://kubernetes.io/docs/setup/)
  * [CodeReady containers](https://access.redhat.com/documentation/en-us/red_hat_openshift_local/2.5)
  * [minikube](https://minikube.sigs.k8s.io/docs/start/)
* Deploy AWX using the [awx-operator](https://github.com/ansible/awx-operator#basic-install)
* [Create an OAuth2 token](./docs/create-awx-token.md) for your user in the AWX UI

## Installing the Operator

1. Clone the eda-server-operator

```
git clone git@github.com:ansible/eda-server-operator.git
```

2. Log in to your K8s or Openshift cluster.

```
kubectl login <cluster-url>
```

3. Run the `make deploy` target

```
NAMESPACE=eda IMG=quay.io/ansible/eda-server-operator:latest make deploy
```
> **Note** The `latest` tag is the latest _released_ (tagged) version. The deploy with the latest code in `main` branch, use `IMG=quay.io/ansible/eda-server-operator:main` instead.

> **Note** You can use kustomize directly to dynamically modify things like the operator deployment at deploy time.  For directions on how to install this way, see the [kustomize install docs](./docs/kustomize-install.md).

4. Create an access token in your AWX instance using [these docs](./docs/create-awx-token.md).

5. Once your operator pod comes up, you can create an EDA Server resource by applying the following YAML:

> **Warning**
> At the moment, the quay.io/ansible/eda-server:main image is in a private registry.  To use it, you will need to [create and configure a pull secret](#configuring-an-image-pull-secret).

```yaml
apiVersion: eda.ansible.com/v1alpha1
kind: EDA
metadata:
  name: my-eda
spec:
  automation_server_url: https://awx-host
  automation_server_ssl_verify: yes
```

If you are using Openshift, you can take advantage of automatic Route configuration an EDA custom resource like this:

```yaml
apiVersion: eda.ansible.com/v1alpha1
kind: EDA
metadata:
  name: eda-demo
spec:
  automation_server_url: https://awx-host
  automation_server_ssl_verify: yes
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
  api_image: myorg/my-custom-eda
  api_image_version: latest
  ui_image: myorg/my-custom-eda
  ui_image_version: latest
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

2. Then, create a k8s secret from your .docker/config.json file.

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
