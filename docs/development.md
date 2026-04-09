# Development Guide

There are development yaml examples in the [`dev/`](../dev) directory and Makefile targets that can be used to build, deploy and test changes made to the eda-server-operator.

Run `make help` to see all available targets and options.


## Prerequisites

You will need to have the following tools installed:

* [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
* [podman](https://podman.io/docs/installation) or [docker](https://docs.docker.com/get-docker/)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [oc](https://docs.openshift.com/container-platform/4.11/cli_reference/openshift_cli/getting-started-cli.html) (if using OpenShift)

You will also need a container registry account. This guide uses [quay.io](https://quay.io), but any container registry will work.

If you don't already have a k8s cluster, you can use minikube to start a lightweight cluster locally by following the [minikube test cluster docs](minikube-test-cluster.md).


## Registry Setup

1. Go to [quay.io](https://quay.io) and create a repository named `eda-server-operator` under your username.
2. Login at the CLI:
```sh
podman login quay.io
```

> **Note**: The first time you run `make up`, it will create quay.io repos on your fork. You will need to either make those public or create a global pull secret on your cluster.


## Build and Deploy

EDA requires a running AWX instance. Make sure you are logged into your cluster (`oc login` or `kubectl` configured), then run:

```sh
# Discover the AWX URL from your cluster (AWX_NAMESPACE defaults to 'awx')
make awx-url AWX_NAMESPACE=awx

# Deploy EDA with the AWX URL
AUTOMATION_SERVER_URL=https://your-awx-route QUAY_USER=username make up
```

This will:
1. Login to container registries
2. Create the target namespace
3. Build the operator image and push it to your registry
4. Deploy the operator via kustomize
5. Apply dev secrets and create a dev EDA instance configured to connect to AWX

### Customization Options

| Variable | Default | Description |
|----------|---------|-------------|
| `QUAY_USER` | _(required)_ | Your quay.io username |
| `AUTOMATION_SERVER_URL` | _(required)_ | AWX URL for EDA to connect to (use `make awx-url` to discover) |
| `AWX_NAMESPACE` | `awx` | Namespace where AWX is running (used by `make awx-url`) |
| `NAMESPACE` | `eda` | Target namespace |
| `DEV_TAG` | `dev` | Image tag for dev builds |
| `CONTAINER_TOOL` | `podman` | Container engine (`podman` or `docker`) |
| `PLATFORM` | _(auto-detected)_ | Target platform (e.g., `linux/amd64`) |
| `MULTI_ARCH` | `false` | Build multi-arch image (`linux/arm64,linux/amd64`) |
| `DEV_IMG` | `quay.io/<QUAY_USER>/eda-server-operator` | Override full image path (skips QUAY_USER) |
| `BUILD_IMAGE` | `true` | Set to `false` to skip image build (use existing image) |
| `CREATE_CR` | `true` | Set to `false` to skip creating the dev EDA instance |
| `CREATE_SECRETS` | `true` | Set to `false` to skip creating dev secrets |
| `IMAGE_PULL_POLICY` | `Always` | Set to `Never` for local builds without push |
| `BUILD_ARGS` | _(empty)_ | Extra args passed to container build (e.g., `--no-cache`) |
| `DEV_CR` | `dev/eda-cr/eda-openshift-cr.yml` | Path to the dev CR to apply |
| `PODMAN_CONNECTION` | _(empty)_ | Remote podman connection name |

Examples:

```bash
# Use a specific namespace and tag
QUAY_USER=username NAMESPACE=eda DEV_TAG=mytag make up

# Use docker instead of podman
CONTAINER_TOOL=docker QUAY_USER=username make up

# Build for a specific platform (e.g., when on ARM building for x86)
PLATFORM=linux/amd64 QUAY_USER=username make up

# Deploy without building (use an existing image)
BUILD_IMAGE=false DEV_IMG=quay.io/myuser/eda-server-operator:latest make up
```

### Accessing the Deployment

On **OpenShift**:
```sh
oc get route
```

On **k8s with ingress**:
```sh
kubectl get ing
```

On **k8s with nodeport**:
```sh
kubectl get svc
```
The URL is then `http://<Node-IP>:<NodePort>`.

> **Note**: NodePort will only work if you expose that port on your underlying k8s node, or are accessing it from localhost.

### Default Credentials

The dev CR pre-creates an admin password secret. Default credentials are:
- **Username**: `admin`
- **Password**: `password`

Without the dev CR, a password would be generated and stored in a secret named `<deployment-name>-admin-password`.


## Clean up

To tear down your development deployment:

```sh
make down
```

### Teardown Options

| Variable | Default | Description |
|----------|---------|-------------|
| `KEEP_NAMESPACE` | `false` | Set to `true` to keep the namespace for reuse |
| `DELETE_PVCS` | `true` | Set to `false` to preserve PersistentVolumeClaims |
| `DELETE_SECRETS` | `true` | Set to `false` to preserve secrets |

Examples:

```bash
# Keep the namespace for faster redeploy
KEEP_NAMESPACE=true make down

# Keep PVCs (preserve database data between deploys)
DELETE_PVCS=false make down
```


## Testing

### Linting

Run linting checks (required for all PRs):

```sh
make lint
```


## Bundle Generation

If you have the Operator Lifecycle Manager (OLM) installed, you can generate and deploy an operator bundle:

```bash
# Generate bundle manifests and validate
make bundle

# Build and push the bundle image
make bundle-build bundle-push

# Build and push a catalog image
make catalog-build catalog-push
```

After pushing the catalog, create a `CatalogSource` in your cluster pointing to the catalog image. Once the CatalogSource is in a READY state, the operator will be available in OperatorHub.
