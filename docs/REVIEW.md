# Engineering review — 2026-09-06

## Release status

This is a test candidate, not an end-to-end certified production release.
The prior local build at Docker commit `7007505` completed all four images.
Portal returned HTTP 200, the three Node roots returned HTTP 302, MySQL was
healthy, and Worker/Local contained NCL 6.6.2 and 13 scripts. These checks do
not prove data indexing, distributed registration or analysis output correctness.

## Findings and corrections

1. **MySQL grouping compatibility:** `ModelFileDao.xml:queryDistinctModel`
   selects `wn.id`/`wn.name` outside its grouping columns. Compose omitted the
   SQL-mode adjustment required by the source README. The server command now
   excludes ONLY_FULL_GROUP_BY while retaining the remaining MySQL strict modes.
2. **First installation:** manual secret instructions were incomplete. Added
   Windows/Linux helpers with random credentials, matching JDBC/Portal passwords,
   correct per-mode database names and refusal to overwrite existing files.
3. **Image lock:** earlier example keys did not match Compose variables and no
   command loaded the file. Corrected the format and documented `--env-file`.
   Added a configurable MySQL image so all five delivered images can be locked.
4. **Mode isolation:** Worker and Local default to the same database. Do not run
   both in a shared project; prior simultaneous startup was an infrastructure
   probe only. Use separate projects to test different deployment modes.
5. **Secret verification:** testing absence of a nonexistent filename inside a
   running container does not prove secrets were excluded from the image.
   Verify actual mount paths separately, and inspect pristine images without
   Compose mounts. Exclude secrets/data from both Git and Docker build context.

## Preserved choices and remaining work

- One WAR plus mounted JDBC overrides is implemented in the pinned source's
  Spring configuration. A Compose profile chooses containers; the web form
  persists the actual deployment mode. Do not call profile startup automatic
  application deployment. Central/Worker/Local all remain supported.
- Application gitlinks pin Node `17372529b3c12e080824e8639f9f7fc515cc228f`
  and Portal `621d1ffd149221551b601b6be9e9e4ecc392c63b`. The 13 ECS scripts
  are tracked directly. CAFE_DATA is a separate read-only host mount.
- Node 24 is a build-stage choice, not an established application requirement;
  Node 12 runtime preserves the locked sqlite3 ABI. No dependency migration was
  authorized for this release. The builder reported 186 advisories (31 critical)
  across its full dependency tree; this is not a runtime-only vulnerability
  assessment. Defer nonessential updates, but do not claim production safety.
- Source tags alone do not ensure reproducible rebuilds: base tags can move,
  Conda transitive dependencies are solver-selected, and Dockerfile Maven edits
  pin several dependency ranges to old lower bounds. Record the resulting
  inventory and deliver the validated image digest. Future builds should lock
  all base digests and the complete Conda environment before claiming identical
  rebuilds. Do not call that dependency pinning a security upgrade.
- Validated architecture is linux/amd64. ARM64 needs separate validation.
- Full acceptance still needs fresh-database initialization, deployment forms,
  Central/Worker registration, representative NetCDF indexing, Portal login,
  a completed NCL task/result download, and persistence after restart.

## Development history

THU-ESIS owns the upstream repository. Theropod develops a feature branch in
its fork and opens a PR against upstream `main`. An initial upstream README
provides a shared ancestor. Merge commits preserve PR context; tags identify
releases, so a permanent branch per release is unnecessary. Do not delete
existing branches/tags as part of publishing this Docker repository.
