# EDA Server Operator

test-ci

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Code of Conduct](https://img.shields.io/badge/code%20of%20conduct-Ansible-yellow.svg)](https://docs.ansible.com/ansible/latest/community/code_of_conduct.html) 

A Kubernetes operator for Kubernetes built with [Operator SDK](https://github.com/operator-framework/operator-sdk) and Ansible for deploying and maintaining the lifecycle of your [EDA Server](https://github.com/ansible/eda-server) application.

## Overview

This operator is meant to provide a more Kubernetes-native installation method for EDA Server via an EDA Custom Resource Definition (CRD). In the future, this operator will grow to be able to maintain the full life-cycle of an EDA Server deployment. Currently, it can handle fresh installs and upgrades.

Table of Contents
=================

- [EDA Server Operator](#eda-server-operator)
  - [Overview](#overview)
- [Table of Contents](#table-of-contents)
  - [Contributing](#contributing)
    - [Prerequisites](#prerequisites)
  - [Install the EDA Server Operator](#install-the-eda-server-operator)
  - [Deploy EDA](#deploy-eda)
  - [Upgrades](#upgrades)
  - [Advanced Configuration](#advanced-configuration)
    - [Admin user account configuration](#admin-user-account-configuration)
    - [Database Fields Encryption Configuration](#database-fields-encryption-configuration)
    - [Additional Advanced Configuration](#additional-advanced-configuration)
  - [Maintainers Docs](#maintainers-docs)

<!-- Created by https://github.com/ekalinin/github-markdown-toc -->

## Contributing

Please visit [our contributing guide](./CONTRIBUTING.md) which has details about how to set up your development environment.

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

> [!Note]
> If you want to do a single-command install with no modifications, please see these docs [here](./docs/single-command-install.md).

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

Once deployed, the EDA instance will be accessible by running:

```
$ minikube service -n eda eda-demo-service --url
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

If using Openshift, EDA instance will be accessible by running:

```
$ oc get route -n eda eda-demo
```

By default, the admin user is `admin` and the password is available in the `<resourcename>-admin-password` secret. To retrieve the admin password, run:

```bash
$ kubectl get secret eda-demo-admin-password -o jsonpath="{.data.password}" | base64 --decode ; echo
yDL2Cx5Za94g9MvBP6B73nzVLlmfgPjR
```

## Upgrades

We recommend you take an backup by creating an EDABackup resource before upgrading, particularly if the new version includes a PostgreSQL database version change.

For information on how to upgrade, please see the [upgrading.md](./docs/upgrade/upgrading.md).

## Advanced Configuration

### Admin user account configuration

There are three variables that are customizable for the admin user account creation.

| Name                  | Description                                  | Default          |
| --------------------- | -------------------------------------------- | ---------------- |
| admin_user            | Name of the admin user                       | admin            |
| admin_password_secret | Secret that contains the admin user password | Empty string     |


> :warning: **admin_password_secret must be a Kubernetes secret and not your text clear password**.

If `admin_password_secret` is not provided, the operator will look for a secret named `<resourcename>-admin-password` for the admin password. If it is not present, the operator will generate a password and create a Secret from it named `<resourcename>-admin-password`.

To retrieve the admin password, run `kubectl get secret <resourcename>-admin-password -o jsonpath="{.data.password}" | base64 --decode ; echo`

The secret that is expected to be passed should be formatted as follow:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: <resourcename>-admin-password
  namespace: <target namespace>
stringData:
  password: mysuperlongpassword
```


### Database Fields Encryption Configuration

This encryption key is used to encrypt sensitive data in the database.

| Name                        | Description                                           | Default          |
| --------------------------- | ----------------------------------------------------- | ---------------- |
| db_fields_encryption_secret | Secret that contains the symmetric key for encryption | Generated        |


> :warning: **db_fields_encryption_secret must be a Kubernetes secret and not your text clear secret value**.

If `db_fields_encryption_secret` is not provided, the operator will look for a secret named `<resourcename>-db-fields-encryption-secret` for the encryption key. If it is not present, the operator will generate a secret value and create a Secret containing it named `<resourcename>-db-fields-encryption-secret`. It is important to not delete this secret as it will be needed for upgrades and if the pods get scaled down at any point. If you are using a GitOps flow, you will want to pass a secret key secret and not depend on the generated one.

The secret should be formatted as follow:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: custom-eda-db-encryption-secret
  namespace: <target namespace>
stringData:
  secret_key: supersecuresecretkey
```

Then specify the name of the k8s secret on the EDA spec:

```yaml
---
spec:
  ...
  db_fields_encryption_secret: custom-eda-db-encryption-secret
```

### Additional Advanced Configuration
- [No Log](./docs/user-guide/advanced-configuration/no-log.md)
- [EDA application settings](./docs/user-guide/advanced-configuration/settings.md)
- [Deploy a Specific Version of EDA](./docs/user-guide/advanced-configuration/deploying-a-specific-version.md)
- [Trusting a Custom Certificate Authority](./docs/user-guide/advanced-configuration/trusting-a-custom-certificate-authority.md)
- [Database Configuration](./docs/user-guide/database-configuration.md)

## Maintainers Docs

Maintainers of this repo need to carry out releases, triage issues, etc. There are docs for those types of administrative tasks in the `docs/maintainer/` directory.

To release the EDA Server Operator, see these docs:
* [Release Operator](./docs/maintainers/release.md)
