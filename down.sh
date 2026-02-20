#!/bin/bash
# EDA Operator down.sh

# -- Usage
#   NAMESPACE=eda ./down.sh

# -- Variables
NAMESPACE=${NAMESPACE:-eda}
TAG=${TAG:-dev}
QUAY_USER=${QUAY_USER:-developer}
IMG=quay.io/$QUAY_USER/eda-server-operator:$TAG
EDA_CR=${EDA_CR:-eda}


# -- Delete Backups
kubectl delete edabackup --all

# -- Delete Restores
kubectl delete edarestore --all

# Delete old operator deployment
kubectl delete deployment eda-server-operator-controller-manager

# Parse command line arguments
ALL_FLAG=false
for arg in "$@"; do
  case $arg in
    --all)
      ALL_FLAG=true
      shift
      ;;
  esac
done

# Deploy Operator
if [ "$ALL_FLAG" = true ]; then
  make undeploy IMG=$IMG NAMESPACE=$NAMESPACE
else
  make undeploy-keep-crd IMG=$IMG NAMESPACE=$NAMESPACE
fi

# Remove PVCs
kubectl delete pvc postgres-15-$EDA_CR-postgres-15-0
