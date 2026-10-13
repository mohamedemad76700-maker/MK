# Architecture Update — MK School V44

> Historical architecture note for V44. It does not report validation of the current V50 release; see [the current review](REVIEW-AND-TEST-REPORT.md).

PostgreSQL is the source of truth for school state. Collections and individual records are stored separately in `platform_state_collections` and `platform_state_items`, using optimistic revision checks and bounded record-level deltas to avoid replacing the entire school payload for each save.

Browser storage APIs (`localStorage`, `sessionStorage`, IndexedDB) are not used for school records, attachments, credentials, or auth tokens. The JavaScript state is an in-memory working view only; users sign in again after a refresh.

Binary attachments are uploaded to the backend, persisted under `MEDIA_ROOT/school-files`, catalogued in PostgreSQL and accessed through short-lived signed links with account/session checks. Authenticated users cannot browse the storage directory directly.

This is a safer synchronization and storage design, not a substitute for operational readiness validation. Production rollout still requires actual PostgreSQL/Redis integration tests, load tests, security review, backup/restore rehearsal and monitoring.
