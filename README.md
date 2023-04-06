# EDA Server Operator

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Code of Conduct](https://img.shields.io/badge/code%20of%20conduct-Ansible-yellow.svg)](https://docs.ansible.com/ansible/latest/community/code_of_conduct.html) 

An [EDA Server](https://github.com/ansible/eda-server) operator for Kubernetes built with [Operator SDK](https://github.com/operator-framework/operator-sdk) and Ansible.

## Purpose

This operator is meant to provide a more Kubernetes-native installation method for EDA Server via an EDA Custom Resource Definition (CRD). In the future, this operator will grow to be able to maintain the full lifecycle of an EDA Server deployment. Currently, it can handle fresh installs and upgrades.

## Install

On the k8s or Openshift variant of your choice, you can install the EDA Server Operator directly from this repo with kustomize.  This can be done by first creating a `kustomization.yaml` file. 
th the followign contents:

```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - config/default

# Set the image tags to match the git version from above
images:
  - name: quay.io/chadams/eda-server-operator
    newTag: dev

# Specify a custom namespace in which to install EDA
namespace: eda
```

Then kustomize and apply it by running:

```
kustomize build . | kubectl apply -f -
```

Once your operator pod comes up, you can create an EDA Server resource by applying the folowing yaml:

```
apiVersion: eda.ansible.com/v1alpha1
kind: EDA
metadata:
  name: my-eda
spec:
  no_log: true
```