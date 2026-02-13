# SomethingNeedDoing Code Quality Audit

## Purpose

This living document tracks code-quality audit findings for addon-owned runtime modules, prioritizes remediation, and defines a repeatable validation baseline for future changes.

## Last Updated

- Date: 2026-02-13
- Audit scope owner: Architecture review pass
- Scope policy: Addon-owned modules only, excluding bundled libraries under `SomethingNeedDoing/libs/`

## Scope Reviewed Modules and Files

- [`SomethingNeedDoing/docs/ARCHITECTURE.md`](SomethingNeedDoing/docs/ARCHITECTURE.md)
- [`SomethingNeedDoing/Core.lua`](SomethingNeedDoing/Core.lua)
- [`SomethingNeedDoing/Comms.lua`](SomethingNeedDoing/Comms.lua)
- [`SomethingNeedDoing/DB.lua`](SomethingNeedDoing/DB.lua)
- [`SomethingNeedDoing/Roster.lua`](SomethingNeedDoing/Roster.lua)
- [`SomethingNeedDoing/Scanner.lua`](SomethingNeedDoing/Scanner.lua)
- [`SomethingNeedDoing/Options.lua`](SomethingNeedDoing/Options.lua)
- [`SomethingNeedDoing/UI.lua`](SomethingNeedDoing/UI.lua)

## Architecture Snapshot Summary

- Addon is a single-process event-driven WoW client module graph centered on `SND` initialization and shared SavedVariables state.
- Runtime flow is scan-heavy and comms-heavy: profession scanning updates local store, then publishes via guild addon channel.
- Data propagation combines LWW merge semantics with periodic full-state rebroadcast.
- UI consumes mutable shared state directly and refreshes tab-local views after events.
- Main risk concentration areas: comms throughput, merge churn, scan-to-publish coupling, and silent truncation limits.

## Findings

### Critical

- No critical findings in this pass.

### High

#### H-01: Guild membership check is O roster size per inbound addon message

- **Anchor:** [`SND:IsGuildMember()`](SomethingNeedDoing/Comms.lua:548), [`GetGuildRosterInfo` loop](SomethingNeedDoing/Comms.lua:554)
- **Issue:** Every inbound comm invokes a full guild roster scan to validate sender membership.
- **Impact:** Scales poorly under burst traffic and large guild rosters; can increase frame-time variance during sync bursts.
- **Recommendation:** Maintain a cached membership set refreshed from roster events, then perform O1 lookups in comms hot path.

#### H-02: Legacy recipe transport remains enabled by default, doubling publish pressure

- **Anchor:** [`sendLegacyRecipeChunks default`](SomethingNeedDoing/Comms.lua:96), [`legacy chunk send loop`](SomethingNeedDoing/Comms.lua:379)
- **Issue:** Recipe index publishes via both modern envelope and legacy chunk protocol by default.
- **Impact:** Increased guild channel bandwidth, higher processing overhead, and additional rate-limit contention.
- **Recommendation:** Gate legacy transport behind explicit compatibility mode and disable by default for homogeneous client versions.
- **Status (2026-02-13):** Implemented. Legacy recipe chunk transport now defaults to disabled; compatibility mode remains available by explicitly enabling `sendLegacyRecipeChunks`.

### Medium

#### M-01: Recipe metadata version increments on every scan update even when payload is unchanged

- **Anchor:** [`version increment and timestamp overwrite`](SomethingNeedDoing/Scanner.lua:947)
- **Issue:** Existing recipe entries always receive new version and timestamps once touched.
- **Impact:** Causes avoidable LWW churn, larger sync deltas, and unnecessary downstream UI refreshes.
- **Recommendation:** Compute structural diff before mutating metadata; only bump `version` and timestamps on actual field changes.
- **Status (2026-02-13):** Implemented. `EnsureRecipeIndexEntry` now tracks whether any recipe payload fields actually changed and only updates `version`, `updatedAtServer`, `updatedBy`, and `lastUpdated` when a change is detected.

#### M-02: Shared mats snapshot truncates at fixed cap without explicit observability

- **Anchor:** [`maxItems = 200`](SomethingNeedDoing/Scanner.lua:1030), [`early return on cap`](SomethingNeedDoing/Scanner.lua:1039)
- **Issue:** Snapshot collection exits at 200 items with no persisted telemetry or user-facing indication.
- **Impact:** Partial material visibility can mislead request planning and diagnostics.
- **Recommendation:** Emit bounded warning telemetry and expose truncated-count indicator in UI or debug output.
- **Status (2026-02-13):** Implemented. `SnapshotSharedMats` now computes truncation telemetry (`captured`, `truncated`, `totalCandidates`), persists bounded snapshot metadata on `SND.scanner`, and emits a rate-limited debug warning when truncation occurs.

#### M-03: Debounced publish uses fixed 30-second gate without queued follow-up publish

- **Anchor:** [`DebouncedPublish` gate](SomethingNeedDoing/Scanner.lua:988)
- **Issue:** Calls inside cooldown return early and rely on future triggers rather than guaranteed trailing publish.
- **Impact:** Data freshness can lag after dense event windows; remote peers may observe stale state longer than intended.
- **Recommendation:** Implement trailing-edge scheduling so at least one publish occurs after cooldown expiry.
- **Status (2026-02-13):** Implemented. `DebouncedPublish` now schedules one trailing publish when called during cooldown, coalesces repeated calls into a single pending timer, and publishes immediately once cooldown expires.

### Low

#### L-01: Default minimap visibility values are internally inconsistent

- **Anchor:** [`DEFAULT_DB.config.showMinimapButton = true`](SomethingNeedDoing/DB.lua:20), [`SND:EnsureDBDefaults()` minimap normalization](SomethingNeedDoing/DB.lua:106)
- **Issue:** Static defaults and migration-time fallback diverge on minimap-button visibility.
- **Impact:** Non-deterministic first-run behavior across profiles/migrations; harder support triage.
- **Recommendation:** Consolidate to one source of truth and migration rule, then document expected initial state.
- **Status (2026-02-13):** Implemented. Minimap visibility defaults now resolve from one canonical source (`DEFAULT_DB.config.showMinimapButton = true`) and migration normalization deterministically synchronizes `showMinimapButton` with `minimapIconDB.hide` when present.

#### L-02: Profession scan helpers duplicate normalization logic across trade-skill and craft paths

- **Anchor:** [`normalizeProfessionName` shared helper](SomethingNeedDoing/Scanner.lua:81), [`usage in trade-skill scan`](SomethingNeedDoing/Scanner.lua:300), [`usage in craft scan`](SomethingNeedDoing/Scanner.lua:473)
- **Issue:** Equivalent helper logic appears in multiple scanning routines.
- **Impact:** Increases maintenance surface and divergence risk for edge-case normalization behavior.
- **Recommendation:** Extract shared helpers into one local utility region and reuse across both scan paths.
- **Status (2026-02-13):** Implemented. Shared nil-safe helper functions are now defined once and reused by both `ScanProfessions` and `ScanCraftProfessions` without changing call-site behavior.

## Top 5 Quick Wins

1. Cache guild roster membership map for [`SND:IsGuildMember()`](SomethingNeedDoing/Comms.lua:548) lookups.
2. Disable legacy recipe chunking by default in [`SND:InitComms()`](SomethingNeedDoing/Comms.lua:91).
3. Add change-detection guard before mutating recipe metadata in [`SND:EnsureRecipeIndexEntry()`](SomethingNeedDoing/Scanner.lua:910).
4. Add trailing-edge publish scheduling in [`SND:DebouncedPublish()`](SomethingNeedDoing/Scanner.lua:988).
5. Log and surface shared-mats truncation when cap is reached in [`SND:SnapshotSharedMats()`](SomethingNeedDoing/Scanner.lua:1027).

## Prioritized Implementation Roadmap

### Phase 1

- Optimize comms hot path by replacing roster scan validation with cached guild-member set.
- Disable legacy recipe transport by default and verify mixed-version fallback behavior.
- Add deterministic trailing publish scheduling to reduce stale-state windows.

### Phase 2

- Introduce recipe-entry structural diffing to suppress no-op version churn.
- Add snapshot truncation observability plus UI/debug visibility for partial mats datasets.
- Consolidate duplicated scan normalization helpers.

### Phase 3

- Add lightweight comms/scan metrics counters for ongoing quality regression detection.
- Harden documentation and config consistency rules for migration-sensitive defaults.
- Re-audit UI refresh coupling points for unnecessary redraws and expensive list rebuilds.

## Validation Checklist for Future PRs

- [ ] Comms path remains O1 for sender membership checks in steady state.
- [ ] Recipe publish path sends one canonical transport unless compatibility mode is explicitly enabled.
- [ ] Recipe version/timestamp fields change only when recipe payload fields change.
- [ ] Debounced publish guarantees a trailing publish after cooldown during burst updates.
- [ ] Shared mats snapshot reports truncation when item cap is reached.
- [x] Config defaults and migration fallback values are internally consistent.
- [x] New scan helper logic is reused instead of duplicated across trade/craft paths.
- [ ] Any new finding entry includes anchor, issue, impact, and recommendation.

## How to Update This Document

1. Re-run targeted review on changed addon-owned files only.
2. Add or update findings under severity group with this template:
   - Anchor link to file and line.
   - Issue statement.
   - User/system impact.
   - Concrete recommendation.
3. Re-rank quick wins and roadmap phases if priorities shift.
4. Update `Last Updated` date and scope notes.
5. Append one new row to the change log with summary of edits.
6. Keep historical findings unless explicitly resolved; mark resolved status inline when applicable.

## Change Log

| Date | Author | Summary |
| --- | --- | --- |
| 2026-02-13 | Code implementation pass | Implemented low-priority consistency cleanup: aligned minimap default/migration normalization to a single canonical `showMinimapButton` source of truth and extracted shared nil-safe profession-name normalization helpers used by both trade-skill and craft scan paths. |
| 2026-02-13 | Code implementation pass | Implemented M-03 by adding trailing-edge publish scheduling in `DebouncedPublish`: calls during cooldown now enqueue one coalesced follow-up publish via timer and execute automatically after cooldown expiry. |
| 2026-02-13 | Code implementation pass | Implemented M-02 by adding shared-mats snapshot truncation observability in `SnapshotSharedMats`: persisted truncation metadata (`lastSharedMatsSnapshot*`) and emitted bounded, rate-limited debug warning output when cap is exceeded. |
| 2026-02-13 | Code implementation pass | Implemented M-01 by adding change-detection in `EnsureRecipeIndexEntry` so recipe metadata version/timestamps only update when entry fields actually mutate; no-op scans no longer churn recipe metadata. |
| 2026-02-13 | Code implementation pass | Implemented H-02 by changing legacy recipe chunk transport default to disabled in comms init while preserving opt-in compatibility mode; updated finding status. |
| 2026-02-12 | Architecture review pass | Initialized living code-quality audit document with scope, architecture snapshot, severity-grouped findings, quick wins, phased roadmap, PR validation checklist, and update protocol. |
