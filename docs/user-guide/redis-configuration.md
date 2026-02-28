### Redis Removal Notice

> **Important:** Starting with this version of the EDA operator, Redis is **no longer deployed or supported**.
> EDA now uses [dispatcherd](https://github.com/ansible/dispatcherd), a PostgreSQL `pg_notify`-based task queuing system, which eliminates the need for a separate Redis instance entirely.

#### Background

Previous versions of the EDA operator deployed a managed Redis instance (or accepted a user-provided one via `redis.redis_secret`) for task queuing through [RQ (Redis Queue)](https://python-rq.org/). With the introduction of dispatcherd, all task orchestration is now handled natively through PostgreSQL, which EDA already requires for its database.

#### What Changed

| Before (Redis)                              | After (Dispatcherd)                              |
|---------------------------------------------|--------------------------------------------------|
| Managed Redis Deployment provisioned        | No Redis resources created                       |
| `spec.redis` and `spec.redis.redis_secret`  | Removed from the CRD; ignored if still present   |
| `redis_image` / `redis_image_version`       | Removed from the CRD                             |
| `EDA_MQ_*` environment variables            | Removed from all deployment templates            |
| RQ-based task queuing (`rqworker`)          | Dispatcherd (`aap-eda-manage dispatcherd`)       |
| External Redis (BYO) supported              | Not supported; use PostgreSQL                    |

#### Upgrading from a Previous Version

When upgrading from an operator version that included Redis:

1. **No data migration is required.** Redis was used only for transient message queuing (with `emptyDir` storage). All durable task state has always been persisted in PostgreSQL.

2. **Legacy Redis resources are cleaned up automatically.** The operator will delete any existing Redis Deployment, Service, and managed Secret (`<name>-redis-configuration`) during the upgrade reconciliation.

3. **Remove `redis` from your EDA Custom Resource when convenient.** If your CR spec still contains a `redis` section (e.g. `redis.redis_secret`), the operator will **log a deprecation warning** and ignore the configuration entirely. The upgrade will proceed normally. You should remove the `redis:` block from your CR at your earliest convenience:

   ```yaml
   # Before (deprecated — ignored by the operator)
   spec:
     redis:
       redis_secret: my-redis-secret

   # After (recommended)
   spec:
     # redis section removed — no replacement needed
   ```

4. **External (BYO) Redis is no longer used.** If you were providing your own Redis via a secret, you can safely decommission that Redis instance once the EDA operator upgrade is complete. No EDA component connects to Redis anymore.

#### Task Queuing Architecture

EDA's background task processing is now powered entirely by **dispatcherd**:

- **Message broker:** PostgreSQL [`pg_notify` / `LISTEN`](https://www.postgresql.org/docs/current/sql-notify.html) channels replace the Redis pub/sub layer.
- **Task workers:** The `aap-eda-manage dispatcherd` management command replaces `aap-eda-manage rqworker`. A backward-compatible `rqworker` wrapper exists in eda-server that forwards to dispatcherd.
- **Scheduler:** Periodic task scheduling is integrated into the dispatcherd workers; the separate scheduler pod has been removed.
- **Health checks:** Dispatcherd exposes worker health checks through the EDA status API endpoint.

No additional configuration is needed — dispatcherd uses the same PostgreSQL database that EDA already requires, with connection details sourced from `database.database_secret`.

#### Q&A

**Q: Can I still use Redis with EDA?**
A: No. The `spec.redis` CRD fields have been removed. If they are still present in your CR (e.g. from a previous version), the operator will ignore them and log a deprecation warning.

**Q: Do I need to change my PostgreSQL sizing?**
A: In most deployments, no. Dispatcherd's use of `pg_notify` adds negligible overhead.
