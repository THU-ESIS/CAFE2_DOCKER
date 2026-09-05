# Build, publish and hand off images

## Recommended distribution

Use GHCR for Docker images and a GitHub Release for the deployment bundle,
version notes, `images.lock`, source commit IDs and SHA-256 checksums. Testers
pull the exact validated digests; they do not rebuild. New GHCR packages may
start private even for public repositories: verify visibility and test an
unauthenticated pull before announcing a public download.

GitHub's automatic source ZIP is not a complete source build bundle because
it does not include submodule contents. Build users must clone recursively.
The image deployment bundle must include compose.yaml, .env.example,
mysql/init, scripts, README/docs and the release's real images.lock. Include
Dockerfiles if shipping the same Compose file with build definitions. Never
include secrets, .env, datasets, database volumes or private logs.

## Maintainer procedure

1. Develop on Theropod's fork, validate the PR and merge to THU-ESIS/main.
2. Create an annotated Docker release tag on the reviewed merge commit. Source
   repositories already have v1.11.0; the Docker package can use a prerelease
   such as v1.11.0-rc.1 while application acceptance remains incomplete. Tags in
   different repositories are independent. Never move an existing release tag.
3. In a clean recursive checkout of that tag, build all application images:

   ```bash
   docker compose build central worker local portal
   ```

4. Test the resulting images against a fresh database in a separate Compose
   project. Complete the application acceptance checklist in REVIEW.md and
   record which checks actually passed. Record source revisions, build platform,
   image IDs and dependency inventory. Do not rebuild between validation and push.
5. Authenticate to GHCR through the maintainer's normal login or a GitHub Actions
   workflow using its repository-scoped GITHUB_TOKEN. Do not commit a PAT.
   Tag/push each tested image (example; replace RELEASE_TAG):

   ```bash
   docker tag cafe2-v1-worker:latest ghcr.io/thu-esis/cafe2-worker:RELEASE_TAG
   docker push ghcr.io/thu-esis/cafe2-worker:RELEASE_TAG
   docker buildx imagetools inspect ghcr.io/thu-esis/cafe2-worker:RELEASE_TAG
   ```

   Repeat for portal, central and local. Record **registry manifest digests**,
   not an arbitrary local config ID, in the five Compose variables illustrated
   by images.lock.example. Resolve and include the tested MySQL manifest too.
6. Pull those digests on a clean test host and verify startup/use. Publish the
   deployment bundle and checksums in a GitHub prerelease/release only after
   this succeeds. A CI rebuild creates a new artifact and must be validated;
   it is not automatically identical to a locally tested image.

## Offline copy

An image archive can deliver the same image bytes without registry access.
For the current local-mode image names, export all required images:

```bash
docker image save -o cafe2-local-images.tar cafe2-v1-local:latest cafe2-v1-portal:latest mysql:8.0.46
```

Send it together with the matching deployment bundle, image IDs and a checksum.
Windows: `Get-FileHash cafe2-local-images.tar -Algorithm SHA256`.
Linux: `sha256sum cafe2-local-images.tar`.
The receiver verifies the checksum, then runs:

```bash
docker image load -i cafe2-local-images.tar
# Configure new secrets and .env using README before starting.
docker compose --profile local up -d --no-build --pull never
```

Use local image tags in .env for this archive mode; registry digest references
may not resolve from a docker-save archive. Keep the source image IDs in the
handoff record and check them after load. Central/Worker installations need
their respective images exported as well. Use `save/load`, not container
`export/import`, to preserve image metadata and layers. Application data and
secrets are supplied by the recipient; they are not part of the image archive.

Large tar files are best delivered through a registry or file-transfer service.
GitHub Release assets have a per-file size limit; check the actual archive size
against the current GitHub limits before uploading. Do not commit image tar
files to Git history.

References: [GHCR documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry),
[GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases),
[docker image save](https://docs.docker.com/reference/cli/docker/image/save/).
