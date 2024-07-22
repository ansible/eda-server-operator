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

# Deploy Operator
make undeploy IMG=$IMG NAMESPACE=$NAMESPACE

# Remove PVCs
kubectl delete pvc postgres-15-$EDA_CR-postgres-15-0

