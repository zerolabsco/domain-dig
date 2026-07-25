# DomainDig Data Migration Policy

How DomainDig's persisted data evolves across app versions without losing or
corrupting a user's on-device store.

## What is persisted

The store is a set of independent JSON blobs in `UserDefaults`, each under a
stable key (see `DomainDataPortabilityService.StorageKey`):

| Data | Key |
|------|-----|
| Tracked domains | `trackedDomains` (legacy: `watchedDomains`) |
| Lookup history (snapshots) | `lookupHistory` |
| Audit sessions | `domainAudits` |
| Workflows | `domainWorkflows` |
| Monitoring settings / logs | `monitoring.settings`, `monitoring.logs` |
| App settings | `recentSearches`, `savedDomains`, resolver URL, density |
| Feature metadata | `purchase.cachedEntitlement`, `usageCredits.ledger` |

A **backup export** (`DomainDigBackup`) is a separate, self-describing file that
bundles all of the above with its own `schemaVersion`.

## Two version lines

- **Store schema version** — `DataMigrationService.currentStoreSchemaVersion`,
  persisted under `data.storeSchemaVersion`. Describes the shape of the
  *on-device* `UserDefaults` store. Advanced by the migration runner.
- **Backup schema version** — `DomainDigBackup.currentSchemaVersion`, written
  into every exported file. Describes the shape of an *export*. Checked on import
  by `DataValidationService`.

They advance independently: a store migration that doesn't change the export
shape need not bump the backup version, and vice versa.

## How models evolve

Prefer **additive, lenient decoding** — it needs no migration:

- New optional field → add it with `decodeIfPresent(...) ?? default` in the
  model's `init(from:)`. Old data simply lacks the key and falls back.
- New value in a `String`-backed enum → decode unknown values to a safe default
  rather than throwing.

Reach for a **migration step** only when lenient decoding can't express the
change:

- Renaming or removing a storage key (e.g. `watchedDomains` → `trackedDomains`).
- Re-normalizing existing rows (dedup, canonicalizing domain casing).
- Reshaping a blob in a way old readers would misread.

## The migration runner

`DataMigrationService.migrateIfNeeded(defaults:)` runs at launch (and before any
backup export/import). Its contract:

1. **Forward-only.** It reads the stored version and runs each step with a target
   greater than it, in ascending order, up to `currentStoreSchemaVersion`,
   stamping the new version after each step.
2. **Never downgrades.** A store stamped at a version *higher* than this build
   understands (a user who ran a newer build first) is left untouched — no
   rewrite, no data loss.
3. **Idempotent & safe on any state.** Every step must be safe to run on an empty
   store and to re-run, because a downgrade-then-upgrade or a partial run can
   replay it. v1 (the `watchedDomains` drop + dedup normalization) satisfies this
   by loading through the deduplicating loaders and writing back.
4. **Pre-versioning installs.** Before this framework, a boolean marker
   (`data.migrations.v3_4_0`) recorded that the v1 normalization had run. A set
   marker is read as "already at version 1," so v1 never re-runs for those users.

## Adding a migration

1. Add a `case N:` to `DataMigrationService.runMigration(to:defaults:)` and a
   private helper that performs the change.
2. Bump `currentStoreSchemaVersion` to `N`.
3. Make the helper idempotent and safe on an empty/older store.
4. Add a `DataMigrationServiceTests` case that seeds a pre-`N` fixture, runs
   `migrateIfNeeded`, and asserts the upgrade plus the version stamp.
5. If the change also alters the export shape, bump
   `DomainDigBackup.currentSchemaVersion` and update `Docs/local-api.md` /
   backup validation as needed.

## Backup import compatibility

On import, `DataValidationService.validate(backup:)` compares the file's
`schemaVersion` to the current one:

- **Newer** than this build → surfaced as an error (the build can't safely read
  it).
- **Older** → imported under the same lenient decoders and merge/dedup rules that
  govern the live store; a note is surfaced, not an error.

Imported data flows through `migrateIfNeeded` and the same `save*` deduplication
as everything else, so an old backup lands in the store already normalized.
