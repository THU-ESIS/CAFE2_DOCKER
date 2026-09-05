# CAFE2 Docker deployment

This repository packages the CAFE2 v1.11.0 runtime for three CAFE2 node modes:
`central`, `worker`, and `local`, plus the Portal and its MySQL database.
The application sources are pinned as Git submodules to the `v1.11.0` tags.

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
jdbc.url=jdbc:mysql://mysql:3306/CAFEWORKER?defaultCharacterEncoding=utf-8&autoReconnect=true&failOverReadOnly=false&maxReconnects=2
jdbc.username=cafe2
jdbc.password=replace-me
jdbc.driver=com.mysql.cj.jdbc.Driver
```

Use the database name and credentials appropriate for the selected deployment.
The Portal reads its database password and application secret from Compose
secrets at runtime; they are not stored in the image.

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
docker compose --profile local up --no-build
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
CAFE2_PORTAL_IMAGE=ghcr.io/your-org/cafe2-portal:v1.11.0
CAFE2_CENTRAL_IMAGE=ghcr.io/your-org/cafe2-central:v1.11.0
CAFE2_WORKER_IMAGE=ghcr.io/your-org/cafe2-worker:v1.11.0
CAFE2_LOCAL_IMAGE=ghcr.io/your-org/cafe2-local:v1.11.0
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
CAFE2_WORKER_IMAGE=ghcr.io/your-org/cafe2-worker:v1.11.0@sha256:REPLACE_WITH_DIGEST
```

The version tag is readable for humans; the digest identifies the exact image
manifest. Keep the four final references in `images.lock`.

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
same as the original CAFE2 Node installation guide.

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
