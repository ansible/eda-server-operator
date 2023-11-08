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
  automation_server_ssl_verify: yes
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
- [Deploy a Specific Version of EDA](./docs/user-guide/advanced-configuration/deploying-a-specific-version.md)
- [Trusting a Custom Certificate Authority](./docs/user-guide/advanced-configuration/trusting-a-custom-certificate-authority.md)
