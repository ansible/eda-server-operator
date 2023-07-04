#!/usr/bin/env bash

# -- Set Variables

AAP_XY_VERSION=${AAP_XY_VERSION:-2.4}
AAP_XY=$(echo $AAP_XY_VERSION | sed -e 's/\.//g')

# -- Set Fully Qualified Domain Names for k8s modules

find ./roles ./playbooks -type f -name '*.y*ml' \
  -exec sed -i -e "s/ k8s\(.*\):/ kubernetes.core.k8s\1:/g" {} \;

# Use operator_sdk.utils.k8s_status
find ./roles ./playbooks -type f -name '*.y*ml' \
  -exec sed -i -e " s/ kubernetes.core.k8s_status:/ operator_sdk.util.k8s_status:/g" {} \;

# -- Swap out nginx.conf lines

# Path to downstream nginx.conf
sed -i -e "s|/opt/app-root/ui/eda;|/var/lib/ansible-automation-platform/eda/ui;|g" roles/eda/templates/eda.configmap.yaml.j2


# -- Swap out settings

# Swap out media_root path
sed -i -e "s|media_dir: /var/lib/eda/files|media_dir: /var/lib/ansible-automation-platform/eda/media|g" roles/eda/vars/main.yml

# Set default postgresql max_connections to 1024
if ! grep -qF 'name: POSTGRESQL_MAX_CONNECTIONS' roles/postgres/templates/postgres.statefulset.yaml.j2; then
  sed -i -e "/name: POSTGRESQL_DATABASE$/i \\
            - name: POSTGRESQL_MAX_CONNECTIONS\n\
              value: '1024'" roles/postgres/templates/postgres.statefulset.yaml.j2
fi


# -- Inject RELATED_IMAGES_ references

if ! grep -qF 'name: RELATED_IMAGE_EDA' config/manager/manager.yaml; then
  sed -i -e "/fieldPath: metadata.namespace/a \\
        - name: RELATED_IMAGE_EDA\n\
          value: quay.io/ansible/eda-server:latest\n\
        - name: RELATED_IMAGE_EDA_UI\n\
          value: quay.io/ansible/eda-ui:latest\n\
        - name: RELATED_IMAGE_EDA_INIT_CONTAINER\n\
          value: registry.redhat.io/ubi8/ubi-minimal:latest\n\
        - name: RELATED_IMAGE_EDA_REDIS\n\
          value: redis:latest\n\
        - name: RELATED_IMAGE_EDA_POSTGRES\n\
          value: postgres:13" config/manager/manager.yaml
fi


# -- Set default ingress_type to Route

files=(
    roles/eda/defaults/main.yml
)
for file in "${files[@]}"; do
    sed -i -e "s/ingress_type:\ none/ingress_type:\ Route/g" ${file};
done

files=(
    config/crd/bases/eda.ansible.com_edas.yaml
)
for file in "${files[@]}"; do
  if ! grep -qF 'default: Route' ${file}; then
    sed -i -e "/ingress_type:/a \\
                default:\ Route" ${file};
  fi
done
