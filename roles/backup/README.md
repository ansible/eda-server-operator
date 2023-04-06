Backup Role
=========

The purpose of this role is to create a backup of your EDA deployment which includes:
  - custom deployment specific values in the spec section of the EDA custom resource object
  - backup of the postgresql database
  - secret_key, admin_password, and secrets
  - database configuration

Requirements
------------

This role assumes you are authenticated with an Openshift or Kubernetes cluster:
  - The eda-operator has been deployed to the cluster
  - EDA is deployed to via the operator


Usage
----------------

Then create a file named `backup-eda.yml` with the following contents:

```yaml
---
apiVersion: eda.ansible.com/v1alpha1
kind: EDABackup
metadata:
  name: edabackup-2021-04-22
  namespace: my-namespace
spec:
  deployment_name: myeda
```

Note that the `deployment_name` above is the name of the EDA deployment you intend to backup from.  The namespace above is the one containing the EDA deployment that will be backed up.

Finally, use `kubectl` to create the backup object in your cluster:

```bash
$ kubectl apply -f backup-eda.yml
```

The resulting pvc will contain a backup tar that can be used to restore to a new deployment. Future backups will also be stored in separate tars on the same pvc.


Role Variables
--------------

A custom, pre-created pvc can be used by setting the following variables.

```
backup_pvc: 'eda-backup-volume-claim'
```

> If no pvc or storage class is provided, the cluster's default storage class will be used to create the pvc.

This role will automatically create a pvc using a Storage Class if provided:

```
backup_storage_class: 'standard'
backup_storage_requirements: '20Gi'
```

By default, the backup pvc will be created in the same namespace the edabackup object is created in. If you want your backup to be stored
in a specific namespace, you can do so by specifying `backup_pvc_namespace`.  Keep in mind that you will
need to provide the same namespace when restoring.

```
backup_pvc_namespace: 'custom-namespace'
```
The backup pvc will be created in the same namespace the edabackup object is created in.

If a custom postgres configuration secret was used when deploying EDA, it will automatically be used by the backup role.
To check the name of this secret, look at the databaseConfigurationSecret status on your EDA object.

The postgresql pod for the old deployment is used when backing up data to the new postgresql pod.  If your postgresql pod has a custom label,
you can pass that via the `postgres_label_selector` variable to make sure the postgresql pod can be found.

It is also possible to tie the lifetime of the backup files to that of the EDABackup resource object. To do that you can set the
`clean_backup_on_delete` value to true. This will delete the `backupDirectory` on the pvc associated with the EDABackup object deleted.

```
clean_backup_on_delete: true
```

Variable to define resources limits and request for backup CR.
```
backup_resource_requirements:
  limits:
    cpu: "1000m"
    memory: "4096Mi"
  requests:
    cpu: "25m"
    memory: "32Mi"
```

To customize the pg_dump command that will be executed on a backup use the `pg_dump_suffix` variable. This variable will append your provided pg_dump parameters to the end of the 'standard' command. For example to exclude the data from 'main_jobevent' and 'main_job' to decrease the size of the backup use:

```
pg_dump_suffix: "--exclude-table-data 'main_jobevent*' --exclude-table-data 'main_job'"
```

Testing
----------------

You can test this role directly by creating and running the following playbook with the appropriate variables:

```
---
- name: Backup EDA
  hosts: localhost
  gather_facts: false
  roles:
    - backup
```

License
-------

MIT
