# k8s-healthchecks

[Healthchecks](https://github.com/healthchecks/healthchecks) — self-hosted
cron job / heartbeat monitoring. healthchecks.morrisons.site

Single replica (`strategy: Recreate`) backed by SQLite on a 2Gi RWO PVC —
two pods can never run concurrently against the same sqlite file.

## Secrets

`SECRET_KEY` and `SUPERUSER_PASSWORD` are generated once by the
`healthchecks-bootstrap-secrets` PreSync job
(`manifests/scripts/bootstrap.sh`, mirroring `k8s-zot`'s `ensure_password`
idiom: only ever writes a value if one doesn't already exist at that
OpenBao path) and stored at `kv/homelab/k8s-healthchecks/secret-key` and
`kv/homelab/k8s-healthchecks/superuser-password`. An `ExternalSecret`
pulls both into the `healthchecks` Secret, consumed by the main
Deployment via `secretKeyRef` (never `envFrom`).

## Superuser bootstrap

The current `healthchecks/healthchecks` image does **not** auto-create a
superuser from `SUPERUSER_EMAIL`/`SUPERUSER_PASSWORD` env vars — that
historical feature isn't present in `docker/run.sh` or the current
self-hosting docs as of v5.0.3; the docs call for running
`manage.py createsuperuser` interactively. Since Healthchecks uses the
stock Django `User` model (no `AUTH_USER_MODEL` override), this instead
runs as a separate `healthchecks-create-superuser` **PostSync** job
(`manifests/scripts/create-superuser.sh`) that calls `manage.py migrate`
(a no-op safety net — the main pod's own `run.sh` already migrates on
start) and then creates the `admin` user via an idempotent
`manage.py shell -c` check, only if it doesn't already exist.

This has to be PostSync, not PreSync alongside the secrets job: it needs
the app's own image, the PVC, and the `healthchecks` Secret (populated by
the ExternalSecret) — none of which exist yet during PreSync, since PVC
and ExternalSecret are plain Sync-phase resources. PostSync only runs
once the Deployment reports Healthy, so by the time this job starts, the
Deployment's own first `migrate` has already completed.

## Other deviations from a literal env var list

- `DB_NAME=/data/hc.sqlite` — Healthchecks' default SQLite path is
  `BASE_DIR/hc.sqlite`, inside the container's own ephemeral filesystem,
  not under `/data`. Without this override the PVC mount is pointless;
  the DB would vanish on every pod restart.
- `SECURE_PROXY_SSL_HEADER=X-Forwarded-Proto,https` — Traefik terminates
  TLS and forwards plain HTTP to the pod. Per the project's own
  `docker/README.md`, without this Django can't tell a request was
  secure, and logins fail with "CSRF verification failed".
- Static assets are `collectstatic`'d into the image at build time
  (served via whitenoise) — they do not need to live on the PVC. Only the
  sqlite DB does.