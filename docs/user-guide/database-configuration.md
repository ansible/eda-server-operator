### Database Configuration

#### PostgreSQL Version

The default PostgreSQL version for the version of EDA bundled with the latest version of the eda-server-operator is PostgreSQL 15. You can find this default for a given version by at the default value for [supported_pg_version](./roles/eda/vars/main.yml).

We only have coverage for the default version of PostgreSQL. Newer versions of PostgreSQL will likely work, but should only be configured as an external database. If your database is managed by the operator (default if you don't specify a `database.database_secret`), then you should not override the default version as this may cause issues when operator tries to upgrade your postgresql pod.

#### External PostgreSQL Service

To configure EDA to use an external database, the Custom Resource needs to know about the connection details. To do this, create a k8s secret with those connection details and specify the name of the secret as `database.database_secret` at the CR spec level.


The secret should be formatted as follows:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: <resourcename>-postgres-configuration
  namespace: <target namespace>
stringData:
  host: <external ip or url resolvable by the cluster>
  port: <external port, this usually defaults to 5432>
  database: <desired database name>
  username: <username to connect as>
  password: <password to connect with>
  sslmode: prefer
  type: unmanaged
type: Opaque
```

> Please ensure that the value for the variable `password` should _not_ contain single or double quotes (`'`, `"`) or backslashes (`\`) to avoid any issues during deployment, [backup](./roles/backup) or [restoration](./roles/restore).

> It is possible to set a specific username, password, port, or database, but still have the database managed by the operator. In this case, when creating the postgres-configuration secret, the `type: managed` field should be added.

**Note**: The variable `sslmode` is valid for `external` databases only. The allowed values are: `prefer`, `disable`, `allow`, `require`, `verify-ca`, `verify-full`.

Once the secret is created, you can specify it on your spec:

```yaml
---
spec:
  ...
  database:
    database_secret: <name-of-your-secret>
```

#### Managed PostgreSQL Service

If you don't have access to an external PostgreSQL service, the EDA operator can deploy one for you along side the EDA instance itself.

The following variables are customizable for the managed PostgreSQL service

| Name                                          | Description                                   | Default                                |
| --------------------------------------------- | --------------------------------------------- | -------------------------------------- |
| postgres_image                                | Path of the image to pull                     | quay.io/sclorg/postgresql-15-c9s       |
| postgres_image_version                        | Image version to pull                         | c9s                                    |
| database.resource_requirements                | PostgreSQL container resource requirements    | requests: {cpu: 50m, memory: 100Mi}    |
| database.storage_requirements                 | PostgreSQL container storage requirements     | requests: {storage: 8Gi}               |
| database.postgres_storage_class               | PostgreSQL PV storage class                   | Empty string                           |
| database.priority_class                       | Priority class used for PostgreSQL pod        | Empty string                           |
| database.postgres_data_volume_init                |  Initialize PostgreSQL data directory with the correct permissions | false |

Example of customization could be:

```yaml
---
spec:
  ...
  database:
    resource_requirements:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: '1'
        memory: 4Gi
    storage_requirements:
      requests:
        storage: 8Gi
    postgres_storage_class: fast-ssd
    postgres_data_volume_init: true
    postgres_extra_settings:
      - setting: max_connections
        value: 1000
```

> **Note**: The `postgres_extra_args` parameter is deprecated. Use `postgres_extra_settings` instead to configure PostgreSQL parameters through the postgresql.conf file.

**Note**: If `database.postgres_storage_class` is not defined, PostgreSQL will store it's data on a volume using the default storage class for your cluster.

#### Note about overriding the postgres image

We recommend you use the default image sclorg image. If you override the postgres image to use a custom postgres image like `postgres:15` for example, the default data directory path may be different. These images cannot be used interchangeably.

You can no longer configure a custom `postgres_data_path` because it is hardcoded in the quay.io/sclorg/postgresql-15-c9s image.

#### Note about Postgres data volume initialization

When using a hostPath backed PVC and some other storage classes like longhorn storage, the postgres data directory needs to be accessible by the user in the postgres pod (UID 26).

To initialize this directory with the correct permissions, add `database.postgres_data_volume_init: true` to EDA instance.

```yaml
spec:
  database:
    postgres_data_volume_init: true
```

Should you need to modify the init container commands, there is an example below.

```yaml
spec:
  database:
    postgres_data_volume_init: true
    postgres_init_container_commands: |
      chown 26:0 /var/lib/pgsql/data
      chmod 700 /var/lib/pgsql/data
```

#### Event Stream Database User

The EDA operator automatically creates a dedicated PostgreSQL user (`eda_event_stream`) for event stream operations. This user has minimal privileges (CONNECT only) to reduce the security impact if credentials are exposed in Decision Environments.

> **Important**: The event stream database user must reside on the same PostgreSQL instance as the main EDA database. The `host`, `port`, and `database` fields in the event stream secret should match those of the main EDA database secret — they are used for operator-internal bookkeeping and do not configure a separate database connection.

##### Managed Database

For managed databases (when no `database.database_secret` is specified), the operator automatically:

1. Generates credentials and stores them in a secret named `<instance-name>-event-stream-postgres-configuration`
2. Creates the `eda_event_stream` user with CONNECT privilege on the EDA database
3. Injects the credentials into the event-stream deployment

No additional configuration is required for managed databases.

##### External Database

For external databases, you must manually create the event stream database user before deploying EDA:

1. Create the `eda_event_stream` user with CONNECT privilege:

```sql
CREATE USER eda_event_stream WITH PASSWORD 'your-secure-password';
GRANT CONNECT ON DATABASE eda TO eda_event_stream;
```

2. Create a Kubernetes secret with the event stream database credentials:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: <resourcename>-event-stream-postgres-configuration
  namespace: <target namespace>
stringData:
  username: eda_event_stream
  password: <password>
  database: eda
  port: "5432"
  host: <external postgres host>
  sslmode: prefer
  type: unmanaged
type: Opaque
```

3. Reference the secret in your EDA CR:

```yaml
---
spec:
  ...
  event_stream:
    database_secret: <resourcename>-event-stream-postgres-configuration
```

**Note**: The variable `sslmode` is valid for `external` databases only. The allowed values are: `prefer`, `disable`, `allow`, `require`, `verify-ca`, `verify-full`.
