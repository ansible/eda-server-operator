# Install EDA Server Operator with Kustomize

Some folks may prefer to install the EDA Server Operator using kustomize directly with a personalized kustomize file.  This allows you to easily modify configuration files including the operator's manager deployment itself. To do so, follow the instructions below.  


1. Create a `kustomization.yaml` file with the the following contents. Be sure to change `newTag` to the latest released tag, or the tag you would like to deploy.

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

2. Then kustomize and apply it by running:

```
kustomize build . | kubectl apply -f -
```

For more information on how to use kustomize to modify configuration files dynamically, see these docs:
* Kustomize documentation - https://kustomize.io/
* Using Kustomize to deploy an ansible-operator - https://sdk.operatorframework.io/docs/building-operators/ansible/tutorial/


### Install Latest

It is possible to install the latest available changes from the `main` branch using this approach as well. To do so, you will want a kustomization.yaml file like this:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - github.com/ansible/eda-server-operator/config/default

images:
  - name: quay.io/ansible/eda-server-operator
    newTag: main

# Specify a custom namespace in which to install EDA
namespace: eda
```
