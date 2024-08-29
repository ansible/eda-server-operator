### Redis Configuration

#### Redis Version

The default Redis version for the version of EDA bundled with the latest version of the eda-server-operator is Redis 6.

#### External Redis Service

EDA can be configured to use an external redis cache by creating a secret which holds the configuration values for the external Redis instance.

The secret should be formatted as follows:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: <resourcename>-redis-configuration
  namespace: <target namespace>
stringData:
  host: <external ip or url resolvable by the cluster>
  port: <external port, this usually defaults to 6370>
  redis_tls: <true / false to enable TLS>
  database: <desired database name>
  cluster_endpoint: <optional - see Redis Cluster section>
  username: <username to connect as>
  password: <password to connect with>
  type: unmanaged
type: Opaque
```

The secret should be specified on the EDA customer resource using the following:

```yaml
---
spec:
  ...
  redis:
    redis_secret: <name-of-your-secret>
```

#### Redis Cluster

The format of the cluster_endpoint field is:

"<host>:<port>[,<host>:<port>]*"

This field is required if the external redis service is a cluster.
