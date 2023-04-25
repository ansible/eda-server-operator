# Install EDA Server Operator with Kustomize

Some folks may prefer to install the EDA Server Operator using kustomize directly with a personalized kustomize file.  This allows you to easily modify configuration files including the operator's manager deployment itself. To do so, follow the instructions below.  


1. Create a `kustomization.yaml` file with the the following contents:

```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - config/default

# Set the image tags to match the git version from above
images:
  - name: quay.io/ansible/eda-server-operator
    newTag: stable

# Specify a custom namespace in which to install EDA
namespace: eda
```

2. Then kustomize and apply it by running:

```
kustomize build . | kubectl apply -f -
```

For more information on how to use kustomize to modify configuration files dynamically, see these docs:
* Kustomize documentation - https://kustomize.io/
* Using Kustomize to deploy an ansible-operator - https://sdk.operatorframework.io/docs/building-operators/ansible/tutorial/
