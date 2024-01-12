# Single-Command Installation Guide

This document provides comprehensive instructions for the quick, single-command installation of the EDA Server Operator. Also covered are additional details such as prerequisites, uninstallation, and troubleshooting tips.

## Prerequisites
Before proceeding with the installation, ensure that the following prerequisites are met:

1. **Kubernetes Cluster**: You need an active Kubernetes cluster. If you do not have one, you can set it up using platforms like Minikube, Kind, or a cloud provider like AWS, Azure, or GCP.

2. **kubectl**: The Kubernetes command-line tool, kubectl, should be installed and configured to communicate with your cluster. You can check its availability by running kubectl version.

## Installation
The EDA Server Operator can be installed using a single command. This command applies a YAML file from the EDA Server Operator's GitHub repository directly to your Kubernetes cluster.

Run the following command in your terminal, modifying the version to whichever version you want to install.

```bash
kubectl apply -f https://github.com/ansible/eda-server-operator/releases/download/1.0.0/operator.yaml
```

> [!Note]
> This will create the EDA Server Operator resources in the eda-server-operator-system namespace.

Now create your EDA custom restore by applying the `eda-demo.yml` file and you will soon have a working EDA instance!

```bash
$ kubectl apply -f eda-demo.yaml
```

See the [README.md](../README.md) for more information on configuring EDA by modifying the `spec`.

## Upgrading

## Pre-Upgrade Checklist

* **Backup**: Backup your EDA instance by creating an EDABackup. 
* **Review Release Notes**: Check the release notes for the new version of the EDA Server Operator. This can be found on the GitHub [releases page(https://github.com/ansible/eda-server-operator/releases)]. Pay attention to any breaking changes, new features, or specific instructions for upgrading from your current version.

### Upgrade the Operator

Check the [Releases Page](https://github.com/ansible/eda-server-operator/releases) for the latest EDA Server Operator verion. Copy the URL to the `operator.yaml` artifact for it, then apply it.

For example, if upgrading to version 1.1.0, the command would be:

```bash
kubectl apply -f https://github.com/ansible/eda-server-operator/releases/download/1.1.0/operator.yaml
``````

Monitor the upgrade process by checking the status of the pods in the eda-server-operator-system namespace. You can use the following command:

```bash
kubectl get pods -n eda-server-operator-system
```


## Cleanup
If you wish to remove the EDA Server Operator from your Kubernetes cluster, follow these steps:

Run the following command:

```bash
kubectl delete -f https://github.com/ansible/eda-server-operator/releases/download/1.0.0/operator.yaml
```

