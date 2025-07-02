#!/bin/bash
# EDA Operator up.sh

# -- Usage
#   NAMESPACE=eda TAG=dev QUAY_USER=developer ./up.sh
#   EDA_CR=dev/eda-cr/eda-k8s-ing.yml ./up.sh

# -- User Variables
NAMESPACE=${NAMESPACE:-eda}
QUAY_USER=${QUAY_USER:-developer}
TAG=${TAG:-$(git rev-parse --short HEAD)}
DEV_TAG=${DEV_TAG:-dev}
DEV_TAG_PUSH=${DEV_TAG_PUSH:-true}
EDA_CR=${EDA_CR:-dev/eda-cr/eda-openshift-cr.yml}

# -- Container Build Engine (podman or docker)
ENGINE=${ENGINE:-podman}

# -- Variables
IMG=quay.io/$QUAY_USER/eda-server-operator
KUBE_APPLY="kubectl apply -n $NAMESPACE -f"

# -- Wait for existing project to be deleted
# Function to check if the namespace is in terminating state
is_namespace_terminating() {
    oc get namespace $NAMESPACE 2>/dev/null | grep -q 'Terminating'
    return $?
}

# Check if the namespace exists and is in terminating state
if kubectl get namespace $NAMESPACE 2>/dev/null; then
    echo "Namespace $NAMESPACE exists."

    if is_namespace_terminating; then
        echo "Namespace $NAMESPACE is in terminating state. Waiting for it to be fully terminated..."
        while is_namespace_terminating; do
            sleep 5
        done
        echo "Namespace $NAMESPACE has been terminated."
    fi
fi


# -- Create namespace
kubectl create namespace $NAMESPACE


# -- Prepare

# Set imagePullPolicy to Always
files=(
    config/manager/manager.yaml
)
for file in "${files[@]}"; do
  if grep -qF 'imagePullPolicy: IfNotPresent' ${file}; then
    sed -i -e "s|imagePullPolicy: IfNotPresent|imagePullPolicy: Always|g" ${file};
  fi
done


# Delete old operator deployment
oc delete deployment eda-server-operator-controller-manager

# Create secrets
$KUBE_APPLY dev/secrets/custom-pg-secret.yml
$KUBE_APPLY dev/secrets/custom-db-fields-encryption-secret.yml
$KUBE_APPLY dev/secrets/admin-password-secret.yml


# Create Secrets for testing bundle_cacert_secret
kubectl create -n $NAMESPACE secret generic my-custom-certs --from-file=bundle-ca.crt=/etc/pki/tls/cert.pem


# -- Login to Quay.io
$ENGINE login quay.io

if [ $ENGINE = 'podman' ]; then
  if [ -f "$XDG_RUNTIME_DIR/containers/auth.json" ] ; then
    REGISTRY_AUTH_CONFIG=$XDG_RUNTIME_DIR/containers/auth.json
    echo "Found registry auth config: $REGISTRY_AUTH_CONFIG"
  elif [ -f $HOME/.config/containers/auth.json ] ; then
    REGISTRY_AUTH_CONFIG=$HOME/.config/containers/auth.json
    echo "Found registry auth config: $REGISTRY_AUTH_CONFIG"
  elif [ -f "/home/$USER/.docker/config.json" ] ; then
    REGISTRY_AUTH_CONFIG=/home/$USER/.docker/config.json
    echo "Found registry auth config: $REGISTRY_AUTH_CONFIG"
  else
    echo "No Podman configuration files were found."
  fi
fi

if [ $ENGINE = 'docker' ]; then
  if [ -f "/home/$USER/.docker/config.json" ] ; then
	  REGISTRY_AUTH_CONFIG=/home/$USER/.docker/config.json
    echo "Found registry auth config: $REGISTRY_AUTH_CONFIG"
  else
    echo "No Docker configuration files were found."
  fi
fi


# -- Build & Push Operator Image
echo "Preparing to build $IMG:$TAG ($IMG:$DEV_TAG) with $ENGINE..."
sleep 3
make docker-build docker-push IMG=$IMG:$TAG

# Tag and Push DEV_TAG Image when DEV_TAG_PUSH is 'True'
if $DEV_TAG_PUSH ; then
  $ENGINE tag $IMG:$TAG $IMG:$DEV_TAG
  make docker-push IMG=$IMG:$DEV_TAG
fi

# -- Deploy Operator
make deploy IMG=$IMG:$TAG NAMESPACE=$NAMESPACE

# -- Print Options for EDA CR
echo "Available EDA CR files:"
ls -1 dev/eda-cr

# -- Create CR
echo "Applying EDA CR: $EDA_CR"
$KUBE_APPLY $EDA_CR
