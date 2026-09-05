# Verification record — 2026-09-06

Platform: Docker Desktop Linux engine, linux/amd64. Application source commits
are recorded in REVIEW.md and in the submodule gitlinks.

## Observed results

- Four application images built successfully from the independent repository
  layout. Tests use those built images; the subsequent SQL fix changes the
  MySQL server startup command in Compose, not application image contents.
- Reproduced ERROR 1055 using the existing default MySQL ONLY_FULL_GROUP_BY mode
  and the nonaggregated node columns from `queryDistinctModel`.
- Created isolated project `cafe2-review-20260906` using an empty database volume,
  new helper-generated secrets, empty data directory, and ports 4006/8086.
  MySQL initialized successfully. The same grouping query passed with the fixed
  SQL mode; CAFECENTRAL had 4 tables, CAFEWORKER 6, and CAFEPORTAL 2.
- Portal root and Local deployment form both returned HTTP 200. The Local form
  included LOCAL mode. NCL reported 6.6.2; all 13 snapshot scripts were present.
- Checked each application image in a read-only, network-disabled container
  without Compose mounts: no runtime files in /run/secrets. Separately checked
  that the Local service can read its actual mounted JDBC file.
- Windows configuration helper generated six matching files without a UTF-8
  BOM, refused a second run, and left the existing file hashes unchanged.

## Still required for full acceptance

No real climate dataset was supplied to this isolated verification. Distributed
registration, data indexing/search with representative data, Portal account
flows, NCL task completion and returned plot/data correctness remain unverified
by this record. A release must not present these as passed based on HTTP status.

The GitHub configuration workflow validates Compose/profile syntax and first-
install helper behavior. Its passing status does not replace a build or an
end-to-end scientific analysis test.
