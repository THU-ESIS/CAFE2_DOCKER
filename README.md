# CAFE2 Docker deployment

This repository packages the CAFE2 v1.11.0 runtime for three CAFE2 node modes:
`central`, `worker`, and `local`, plus the Portal and its MySQL database.
The application sources are pinned as Git submodules to the `v1.11.0` tags.

Current status: **test candidate**, with local build/startup verification.
No registry image is published merely by cloning this repository. Check the
Release assets for an actual `images.lock` before using registry image mode.
Read [the engineering review](docs/REVIEW.md), [release procedure](docs/RELEASING.md),
and [Chinese quick start](docs/QUICKSTART.zh-CN.md).
Actual validation coverage is recorded in [TESTING.md](docs/TESTING.md).

## Choose a delivery mode

There are two supported delivery modes:

1. **Build mode**: clone this repository with submodules and build the images
   locally. This is auditable and suitable for development.
2. **Image mode**: set the four `CAFE2_*_IMAGE` variables to published images,
   pull them, and start with `--no-build`. This is preferred for testers who
   need the exact image that was validated by the maintainer.

The Compose profiles are combinations of containers; they do not replace the
CAFE2 deployment modes selected in the web UI.

| Profile | Containers | CAFE2 web deployment mode |
|---|---|---|
| `local` | MySQL + Portal + Local | `LOCAL` |
| `central` | MySQL + Central | `DISTRIBUTED_CENTRAL` |
| `worker` | MySQL + Worker | `DISTRIBUTED_WORKER` |
| `portal` + `worker` | MySQL + Portal + Worker | Portal + Worker |
| `all-in-one` | MySQL + Portal + Central + Worker | Central + Worker |

## Prerequisites

- Docker Desktop with the Linux engine, or Docker Engine with Compose v2.
- Internet access for the first build or image pull.
- A CAFE2 data directory for Local or Worker deployments.
- Runtime secret files described below.
- The validated platform is **linux/amd64**. ARM64 is not validated; NCL and
  the legacy native Node dependency must not be assumed to support it.

Windows users can run the commands from PowerShell. WSL2 is used internally by
Docker Desktop when its Linux engine is enabled; manually entering WSL is not
required.

## Obtain the repository

Use `--recurse-submodules` so the fixed source snapshots are available:

```bash
git clone --recurse-submodules https://github.com/THU-ESIS/CAFE2_DOCKER.git
cd CAFE2_DOCKER
```

If the repository was cloned without submodules:

```bash
git submodule update --init --recursive
```

The submodules point to:

```text
THU-ESIS/CAFE2_NODE:v1.11.0
THU-ESIS/CAFE2_PORTAL:v1.11.0
```

## Configure secrets

Create these files under `secrets/`. They are intentionally ignored by Git:

For a **new installation**, generate mutually consistent random credentials:

```powershell
# Windows PowerShell, from the repository directory
powershell -NoProfile -File scripts/init-config.ps1
Copy-Item .env.example .env
```

```bash
# Linux, requires openssl
sh scripts/init-config.sh
cp .env.example .env
```

Both helpers refuse to overwrite existing credentials. Do not regenerate them
for an existing database volume: MySQL initialization only runs on an empty
volume. Restrict Windows ACLs on `secrets/` to the deployment account; the Linux
helper uses mode 0700 for the directory and 0600 for files.

```text
mysql-root-password
mysql-app-password
portal-app-secret
cafe2-central-jdbc.properties
cafe2-worker-jdbc.properties
cafe2-local-jdbc.properties
```

The Node JDBC files contain the complete runtime properties. For example:

```properties
jdbc.url=jdbc:mysql://mysql:3306/CAFEWORKER?characterEncoding=UTF-8&serverTimezone=UTC&allowPublicKeyRetrieval=true&useSSL=false
jdbc.username=cafe2
jdbc.password=replace-me
jdbc.driver=com.mysql.cj.jdbc.Driver
```

Use the database name and credentials appropriate for the selected deployment.
Central uses `CAFECENTRAL`; Worker and Local each use `CAFEWORKER` in their own
deployment. Do **not** activate Worker and Local simultaneously in the same
Compose project with these defaults: they would share the deployment table.
Use separate project names/directories/ports for independent installations.
All JDBC passwords must equal `mysql-app-password`; the Node username is `cafe2`.
Use UTF-8 **without BOM** when creating files manually.

The example disables TLS only for the bundled MySQL on the private Compose
network (MySQL has no host port). For an external database, configure verified
TLS rather than copying those connection options unchanged.
The Portal reads its database password and application secret from Compose
secrets at runtime; they are not stored in the image.
Ordinary Compose secrets are read-only file mounts, not an encrypted vault:
the application can read them, and a host/Docker administrator can access them.
Do not put them in Dockerfiles, build arguments, Git, image archives or Releases.

Copy `.env.example` to `.env` and set at least:

```dotenv
CAFE_DATA_HOST=/absolute/path/to/CAFE_DATA
```

In PowerShell the equivalent is:

```powershell
$env:CAFE_DATA_HOST = 'D:\CAFE_DATA'
```

`CAFE_DATA_HOST` is mounted read-only as `/CAFE_DATA`; it is not copied into
the image and is not initialized by Compose.

## Build mode

Build the selected profile and start it without rebuilding a second time:

```bash
docker compose --profile local build
docker compose --profile local up -d --no-build
```

Other examples:

```bash
docker compose --profile central build
docker compose --profile central up --no-build

docker compose --profile worker build
docker compose --profile worker up --no-build

docker compose --profile portal --profile worker build
docker compose --profile portal --profile worker up --no-build
```

For the combined Central + Worker setup, point Portal at the Worker service:

```powershell
$env:CAFE_PORTAL_CAFE_WORKER_URL = 'http://worker:8080/datamanager'
docker compose --profile all-in-one build
docker compose --profile all-in-one up --no-build
```

The build creates the Java WAR, installs the fixed NCL 6.6.2 environment in
Worker/Local, and copies the ECS script snapshot into `/CAFE/nclscripts/`.
Changing those scripts requires rebuilding the Worker/Local image.

## Image mode

Image mode uses the same `compose.yaml`, but skips local builds. Put the
published image references in `.env`:

```dotenv
CAFE2_PORTAL_IMAGE=ghcr.io/thu-esis/cafe2-portal:RELEASE_TAG
CAFE2_CENTRAL_IMAGE=ghcr.io/thu-esis/cafe2-central:RELEASE_TAG
CAFE2_WORKER_IMAGE=ghcr.io/thu-esis/cafe2-worker:RELEASE_TAG
CAFE2_LOCAL_IMAGE=ghcr.io/thu-esis/cafe2-local:RELEASE_TAG
```

Then pull and start:

```bash
docker compose --profile local pull
docker compose --profile local up --no-build
```

Use the same profile commands for `central`, `worker`, or `all-in-one`.
If the registry is private, authenticate with the registry before pulling.

For the strongest reproducibility, record the image digest printed after
publishing and use a reference such as:

```dotenv
CAFE2_WORKER_IMAGE=ghcr.io/thu-esis/cafe2-worker@sha256:REPLACE_WITH_DIGEST
```

The version tag is readable for humans; the digest identifies the exact image
manifest. Keep the final references in `images.lock`.
Include `CAFE2_MYSQL_IMAGE` too. **Compose does not load `images.lock`
automatically**; use the supplied release lock explicitly on every command:

```bash
docker compose --env-file .env --env-file images.lock --profile local pull
docker compose --env-file .env --env-file images.lock --profile local up -d --no-build
```

Do not use `images.lock.example` as if it contained real digests. Image-only
users do not need application submodules, Java, Maven, Node or NCL installed
on the host. They still need Compose, `mysql/init`, local secrets and data.

## Access and first configuration

Default host ports are:

```text
Portal  http://localhost:4000
Central http://localhost:8081/datamanager/web/deployment
Worker  http://localhost:8082/datamanager/web/deployment
Local   http://localhost:8083/datamanager/web/deployment
```

After a Node container starts, open its deployment page and select:

- Central container: `DISTRIBUTED_CENTRAL`
- Worker container: `DISTRIBUTED_WORKER`
- Local container: `LOCAL`

For Worker, enter the externally reachable Central address. For Portal, set
`CAFE_PORTAL_CAFE_WORKER_URL` to the reachable Worker or Local endpoint. A
Docker service name such as `worker` is suitable for container-to-container
requests, but public result URLs must use an address reachable by the browser.

## Data indexing

The parent of the standard data directories is submitted on the Node parser
page as `/CAFE_DATA` inside the container. Keep the existing CAFE2 layout and
CF-compliant NetCDF files, for example:

```text
CAFE_DATA/
├─ cmip5_data/
├─ cmip6_data/
└─ observation_data/
```

The exact CMIP5/CMIP6 data request structure and file naming rules remain the
same as the [pinned CAFE2 Node installation guide](https://github.com/THU-ESIS/CAFE2_NODE/blob/v1.11.0/README.md).
After deploying a Worker/Local, use `/datamanager/web/parser` and submit
`/CAFE_DATA`. Open the Portal, register/sign in, check that indexed datasets
appear, submit an analysis, and open/download its result. These are application
acceptance steps; HTTP 200 alone does not validate them.

## Paths inside the containers

These paths match the audited root-level ECS deployment where applicable:

```text
/CAFE_DATA                 read-only host data bind
/CAFE/nclscripts           fixed ECS NCL script snapshot
/CAFE/script_tmp           runtime task output volume
/root/miniconda3/bin/ncl  NCL 6.6.2 compatibility path
/CAFE/log/node             Node logs
/CAFE/log/portal           Portal logs
```

MySQL data is stored in the named `mysql-data` volume. Do not use
`docker compose down -v` unless deleting the local test database is intended.

## Stop and troubleshoot

```bash
docker compose --profile local ps
docker compose --profile local logs --tail=100
docker compose --profile local stop
```

To rebuild after changing Dockerfiles, fixed scripts, or pinned submodules:

```bash
docker compose --profile worker build --no-cache
```

The first successful test should verify that MySQL is healthy, the Node
deployment page returns HTTP 200, NCL reports 6.6.2, and the Worker/Local image
contains the 13 fixed `.ncl` scripts.

MySQL's SQL mode intentionally excludes `ONLY_FULL_GROUP_BY` for the existing
`queryDistinctModel` mapper; other strict checks remain enabled. This matches
the original installation guide without changing application SQL. It also
means ambiguous grouped node columns retain the legacy behavior.

## Backup, upgrades and remote access

Before an upgrade, preserve `.env`, `secrets/`, the exact image lock, and a
consistent MySQL backup plus task output volumes. Stop application writes or
use a consistent database backup method; copying live database files is not a
reliable backup. Restore into a separate project and verify before switching.
New images do not automatically migrate existing schemas; initialization SQL
under `mysql/init` is **not** an upgrade script and must not be rerun on live data.

Defaults publish application ports on all host interfaces. Test on a trusted
network with host firewall restrictions. Do not advertise this legacy test
candidate as hardened for public production: Node 12 and several dependencies
are old, and the build reported security advisories. Public service operation
needs a separate dependency review, access controls and HTTPS configuration.
