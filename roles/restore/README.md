Restore Role
=========

The purpose of this role is to restore your EDA deployment from an existing PVC backup. The backup includes:
  - custom deployment specific values in the spec section of the EDA custom resource object
  - backup of the postgresql database
  - secret_key, admin_password secrets
  - database configuration



Requirements
------------

This role assumes you are authenticated with an Openshift or Kubernetes cluster:
  - The eda-operator has been deployed to the cluster
  - EDA is deployed to via the operator
  - An EDA backup is available on a PVC in your cluster (see the backup [README.md](../backup/README.md))

*Before Restoring from a backup*, be sure to:
  - delete the old existing EDA CR
  - delete the persistent volume claim (PVC) for the database from the old deployment, which has a name like `postgres-15-<deployment-name>-postgres-15-0`

**Note**: Do not delete the namespace/project, as that will delete the backup and the backup's PVC as well.


Usage
----------------

Then create a file named `restore-eda.yml` with the following contents:

```yaml
---
apiVersion: eda.ansible.com/v1alpha1
kind: EDARestore
metadata:
  name: restore1
  namespace: my-namespace
spec:
  deployment_name: myeda
  backup_name: edabackup-2021-04-22
```

Note that the `deployment_name` above is the name of the EDA deployment you intend to create and restore to.

The namespace specified is the namespace the resulting EDA deployment will be in.  The namespace you specified must be pre-created.

```
kubectl create ns my-namespace
```

Finally, use `kubectl` to create the restore object in your cluster:

```bash
$ kubectl apply -f restore-eda.yml
```

This will create a new deployment and restore your backup to it.

> :warning: admin_password_secret value will replace the password for the `admin_user` user (by default, this is the `admin` user).


Role Variables
--------------

The name of the backup directory can be found as a status on your EDABackup object.  This can be found in your cluster's console, or with the client as shown below.

```bash
$ kubectl get edabackup edabackup1 -o jsonpath="{.items[0].status.backupDirectory}"
/backups/eda-openshift-backup-2021-04-02-03:25:08
```

```
backup_dir: '/backups/eda-openshift-backup-2021-04-02-03:25:08'
```


The name of the PVC can also be found by looking at the backup object.

```bash
$ kubectl get edabackup edabackup1 -o jsonpath="{.items[0].status.backupClaim}"
eda-backup-volume-claim
```

```
backup_pvc: 'eda-backup-volume-claim'
```

The backup pvc will be created in the same namespace the edabackup object is created in.


If the edabackup object no longer exists, it is still possible to restore from the backup it created by specifying the pvc name and the back directory.

```
backup_pvc: myoldeda-backup-claim
backup_dir: /backups/eda-openshift-backup-2021-04-02-03:25:08
```

Variable to define resources limits and request for the management pod used by the edarestore CR.

```
restore_resource_requirements:
  limits:
    cpu: "1000m"
    memory: "4096Mi"
  requests:
    cpu: "25m"
    memory: "32Mi"
```

Testing
----------------

You can test this role directly by creating and running the following playbook with the appropriate variables:

```
---
- name: Restore EDA
  hosts: localhost
  gather_facts: false
  roles:
    - restore
```

License
-------

MIT
