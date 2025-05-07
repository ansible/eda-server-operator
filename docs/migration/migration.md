# Migrating data from an old EDA instance

To migrate data from an older EDA installation, you must provide some information via Secrets.

## Creating Secrets for Migration

### DB Fields Encryption Secret

You can find your old DB fields encryption key in the inventory file you used to deploy EDA in previous releases.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <resourcename>-db-fields-encryption-secret
  namespace: <target-namespace>
stringData:
  db_fields_encryption: <old-encryption-key>
type: Opaque
```

!!! note
    `<resourcename>` must match the `name` of the EDA object you are creating. In our example below, it is `eda`.

### Old Database Credentials

The secret should be formatted as follows:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: <resourcename>-old-postgres-configuration
  namespace: <target namespace>
stringData:
  host: <external ip or url resolvable by the cluster>
  port: "<external port, this usually defaults to 5432>"    # quotes are required
  database: <desired database name>
  username: <username to connect as>
  password: <password to connect with>
type: Opaque
```

!!! note
    For `host`, a URL resolvable by the cluster could look something like `postgresql.<namespace>.svc.<cluster domain>`, where `<namespace>` is filled in with the namespace of the EDA deployment you are migrating data from, and `<cluster domain>` is filled in with the internal kubernetes cluster domain (In most cases it's `cluster.local`).

If your EDA deployment is already using an external database server or its database is otherwise not managed by the EDA deployment, you can instead create the same secret as above but omit the `-old-` from the `name`.
In the next section pass it in through `postgres_configuration_secret` instead, omitting the `_old_` from the key and ensuring the value matches the name of the secret. This will make EDA pick up on the existing database and apply any pending migrations.
It is strongly recommended to backup your database beforehand.

The postgresql pod for the old deployment is used when streaming data to the new postgresql pod. If your postgresql pod has a custom label, you can pass that via the `postgres_label_selector` variable to make sure the postgresql pod can be found.

## Deploy EDA

When you apply your EDA object, you must specify the name to the database secret you created above:

```yaml
apiVersion: eda.ansible.com/v1alpha1
kind: EDA
metadata:
  name: eda
spec:
  old_postgres_configuration_secret: <resourcename>-old-postgres-configuration
  db_fields_encryption_secret: <resourcename>-db-fields-encryption-secret
  ...
```

### Exclude PostgreSQL tables during migration (optional)

Use the `pg_dump_suffix` parameter under `EDA.spec` to customize the pg_dump command that will execute during migration. This variable will append your provided pg_dump parameters to the end of the 'standard' command. For example, to exclude the data from specific tables to decrease the size of the backup use:

```
pg_dump_suffix: "--exclude-table-data 'table_name*' --exclude-table-data 'another_table'"
```

### Automatic Cleanup

After a successful migration, the operator will automatically remove the `old_postgres_configuration_secret` reference from the EDA CR. This helps keep your CR clean and avoids keeping unnecessary references to resources that are no longer needed.

## Important Note

If you intend to put all the above in one file, make sure to separate each block with three dashes like so:

```yaml
---
# Secret key

---
# Database creds

---
# EDA Config
```

Failing to do so will lead to an inoperable setup.
