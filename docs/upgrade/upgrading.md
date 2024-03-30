### Upgrading

Before upgrading, please review the changelog for any breaking or notable changes in the releases between your current version and the one you are upgrading to. These changes can be found on the [Release page](https://github.com/ansible/eda-server-operator/releases).


All operator versions pin to the most recent eda-server and ui image version at the time of the operator release by default. This is so that the application version only changes when you upgrade your operator (unless overriden).

To find the version of eda-server that will be installed by the operator, check the version specified in the `DEFAULT_EDA_VERSION` and `DEFAULT_EDA_UI_VERSION` variable for that particular release. You can do so by running the following command

```shell
EDA_OPERATOR_VERSION=1.0.1
docker run --entrypoint="" quay.io/ansible/eda-server-operator:$EDA_OPERATOR_VERSION bash -c "env | egrep "DEFAULT_EDA_VERSION|DEFAULT_EDA_UI_VERSION"
```

Follow the installation instructions ('make deploy', 'kustomization', etc.) using the new release version to apply the new operator yaml and upgrade the operator. This will in turn also upgrade your EDA deployment.

For example, if you installed with kustomize, you could modify the version in your kustomization.yaml file from 1.0.0 to 1.0.1, then apply it. 

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - config/default

# Set the image tags to match the git version from above
images:
  - name: quay.io/ansible/eda-server-operator
    newTag: 1.0.1

# Specify a custom namespace in which to install EDA
namespace: eda
```

Then run this to apply it:

```
kustomize build . | kubectl apply -f -
```

#### Backup

The first part of any upgrade should be a backup. Note, there are secrets in the pod which work in conjunction with the database. Having just a database backup without the required secrets will not be sufficient for recovering from an issue when upgrading to a new version. See the [backup role documentation](./roles/backup/README.md) for information on how to backup your database and secrets.

In the event you need to recover the backup see the [restore role documentation](./roles/restore/README.md). *Before Restoring from a backup*, be sure to:
* delete the old existing EDA CR
* delete the persistent volume claim (PVC) for the database from the old deployment, which has a name like `postgres-15-<deployment-name>-postgres-15-0`

**Note**: Do not delete the namespace/project, as that will delete the backup and the backup's PVC as well.


#### PostgreSQL Upgrade Considerations

If there is a PostgreSQL major version upgrade, after the data directory on the PVC is migrated to the new version, the old PVC is kept by default.
This provides the ability to roll back if needed, but can take up extra storage space in your cluster unnecessarily. By default, the postgres pvc from the previous version will remain unless you manually remove it, or have the `database.postgres_keep_pvc_after_upgrade` parameter set to false. You can configure it to be deleted automatically
after a successful upgrade by setting the following variable on the AWX spec. 

```yaml
  spec:
    database:
        postgres_keep_pvc_after_upgrade: false
```
