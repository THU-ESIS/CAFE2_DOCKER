# CAFE2 Docker

[简体中文](README.zh-CN.md)

Central, Worker and Local deployment with Portal and bundled MySQL.
Platform: **linux/amd64**. This is a test candidate: startup is checked;
real-data indexing and full analysis acceptance remain pending.

## Install published images

Download and extract the deployment archive from [Releases](https://github.com/THU-ESIS/CAFE2_DOCKER/releases).
It includes `images.lock` with the exact image digests. You only need Docker
Engine + Compose v2, or Docker Desktop using Linux containers.

From the extracted directory, generate first-install credentials and copy the settings:

Windows PowerShell:
```powershell
powershell -NoProfile -File scripts/init-config.ps1
Copy-Item .env.example .env
```

Linux (requires openssl):
```sh
sh scripts/init-config.sh
cp .env.example .env
```

Set `CAFE_DATA_HOST` in `.env` to your existing data directory, e.g.
`D:/CAFE_DATA` or `/srv/CAFE_DATA`. Then:
```sh
docker compose --env-file .env --env-file images.lock --profile local pull
docker compose --env-file .env --env-file images.lock --profile local up -d --no-build
```

## Choose a mode

Replace `--profile local` above as needed:

| Profile | Containers | Node deployment form |
|---|---|---|
| local | MySQL + Local + Portal | LOCAL |
| central | MySQL + Central | DISTRIBUTED_CENTRAL |
| worker | MySQL + Worker | DISTRIBUTED_WORKER |
| all-in-one | MySQL + Central + Worker + Portal | Configure both nodes |

For all-in-one, or `--profile portal --profile worker`, set
`CAFE_PORTAL_CAFE_WORKER_URL=http://worker:8080/datamanager` in `.env`.
Do not run local and worker together in the same project: their default database is shared.

Open Portal at http://localhost:4000.
Node deployment pages are `http://localhost:PORT/datamanager/web/deployment`:
Central 8081, Worker 8082, Local 8083. Submit the form once with the mode above,
a reachable host/IP and port, and root path `datamanager`.
A Worker also needs the Central address; the nodes must reach each other.
Container-local `localhost` does not refer to another container.

On Worker/Local, open `/datamanager/web/parser` and index `/CAFE_DATA`.
Keep the original `cmip5_data`, `cmip6_data`, `observation_data` layout
([source guide](https://github.com/THU-ESIS/CAFE2_NODE/blob/v1.11.0/README.md)).
Register/sign in to Portal, find indexed data, submit an analysis and verify its result.
Browser-facing result addresses must be reachable from the user's browser.

## Build from source instead

```sh
git clone --recurse-submodules https://github.com/THU-ESIS/CAFE2_DOCKER.git
cd CAFE2_DOCKER
```

Create credentials and `.env` as above, then:
```sh
docker compose --profile local build
docker compose --profile local up -d --no-build
```

This uses local image tags; do not load a release image lock for local builds.
Application source commits are pinned by submodules. Scripts are included in
Worker/Local images; climate data stays outside at `/CAFE_DATA`.

## Operate safely

Use `docker compose --profile local ps`, `logs --tail=100` or `stop`.
When using image mode, include the same `--env-file .env --env-file images.lock` options.
Credentials in `secrets/` are local files mounted read-only; never upload them.
Helpers refuse to overwrite them; manual configuration is also supported.
They generate database credentials and an application key, not Portal login accounts.
Restrict Windows file permissions to the deployment account.

MySQL initialization runs only on empty volumes. Back up the database, secrets,
settings and task output before upgrades. **Do not use `down -v` on an existing
installation:** it deletes named data volumes. Ports are exposed on the host;
use a trusted test network. Legacy dependencies still need a separate security review.

[Build/release maintenance and offline transfer](docs/MAINTAINING.md)
