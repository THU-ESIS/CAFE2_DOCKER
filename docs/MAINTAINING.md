# Maintenance / 维护

- Develop on a Theropod fork branch, open a PR to THU-ESIS/main, validate and merge.
- In upstream **Actions → Publish GHCR images → Run workflow**, select main and
  a new version such as `v1.11.0-rc.1`. Never reuse a released version.
- Actions builds pinned sources, tests fresh MySQL and node/Portal startup,
  pushes the tested images, records all five digests (including MySQL), then
  creates an annotated tag and a GitHub prerelease with a deployment archive.
- Find images under repository **Packages** or the organization's Packages page.
  On first publication check each package's visibility; it may default to private.
  Public distribution must be verified with an unauthenticated pull.
- Actions uses its temporary GITHUB_TOKEN; no personal token is stored in Git.

开发在 Theropod 的 fork 中进行，经 PR 合并上游。发布从上游 Actions 手动触发，
先构建/检查，再上传镜像。Releases 提供部署包、images.lock 和 SHA256SUMS；
用户使用中英文 README。镜像位于 Packages，首次发布后检查公开可见性。

## Scope / 范围

Source versions are the submodule commits. Node uses Java 21/Tomcat 9; Portal
uses Node 24 to build and Node 12 to run the locked legacy native dependency.
Worker/Local include 13 fixed ECS NCL scripts and NCL 6.6.2. Data remains external.
MySQL's ONLY_FULL_GROUP_BY adjustment follows the original Node README.
Worker/Local defaults share a schema, so use separate projects when running both.

Checks establish build/startup, script presence and database compatibility.
Real NetCDF indexing, distributed registration, Portal account flows and a
complete NCL result still need acceptance testing. Dependencies include known
advisories. Digest locking preserves delivered images, not identical rebuilds
or identical host data/configuration. Original detailed review: PR #1/history.

## Offline / 离线

After pulling a release, tag its selected images locally; for example:
`docker tag ghcr.io/thu-esis/cafe2-local@sha256:ACTUAL_DIGEST cafe2-offline-local:release`.
Do the same for Portal and MySQL (and Central/Worker if needed), then use
`docker image save -o images.tar IMAGE1 IMAGE2 IMAGE3` and record a SHA-256 checksum.
Send the deployment bundle too, never your secrets/data. Receiver verifies the
checksum and runs `docker image load -i images.tar`, sets the CAFE2_*_IMAGE
variables in .env to those local tags, and starts with `--no-build --pull never`
without loading the registry images.lock. Do not use container export/import.

离线传递用 save/load，附部署包和校验值；接收者生成自己的密码并提供自己的数据。
不要直接复制现有容器或数据库来作为镜像交付。
