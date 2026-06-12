# dialyzer_json Roadmap

<!-- VISION:BEGIN -->
AI-friendly JSON output for Dialyzer warnings, optimized for Claude Code and similar tools.
<!-- VISION:END -->

**Completed work:** Phases 1–5 are complete — see [CHANGELOG.md](CHANGELOG.md) for finished-task detail.

> Managed by [rmap](https://github.com/ZenHive/rmap). Edit `roadmap/tasks.toml`, then `rmap render`. Content between marker pairs is generated; prose outside them is preserved.

---

## 🎯 Current Focus

<!-- FOCUS:BEGIN -->
**Focus phase:** 6 — Code Health (static analysis) (0 of 1 done · 0 in progress)

**Last shipped:** no recent shipments

**Up next:** Task 10 — Run Reach static-analysis sweep and act on findings [D:1/B:2/U:2 → Eff:2.0] 🎯
<!-- FOCUS:END -->

---

## Dependency Graph

<!-- MERMAID:BEGIN -->
```mermaid
gantt
    title dialyzer_json
    dateFormat YYYY-MM-DD
    %% no tasks with started_at yet
```
<!-- MERMAID:END -->

---

## Phase 1: Foundation ✅

Basic JSON output, `--quiet`, `--summary-only`, `--group-by-warning`. See CHANGELOG.

<!-- TASKS:BEGIN phase=1 -->
> 0 tasks. See [CHANGELOG.md](CHANGELOG.md#phase-1-foundation-basic-json-output-quiet-summary-only-group-by-warning).
<!-- TASKS:END -->

## Phase 2: Warning Classification ✅

<!-- TASKS:BEGIN phase=2 -->
> 2 tasks. See [CHANGELOG.md](CHANGELOG.md#phase-2-warning-classification-fix-hint).
<!-- TASKS:END -->

## Phase 3: Better Metadata Extraction ✅

<!-- TASKS:BEGIN phase=3 -->
> 2 tasks. See [CHANGELOG.md](CHANGELOG.md#phase-3-better-metadata-extraction).
<!-- TASKS:END -->

## Phase 4: Output Enhancements ✅

<!-- TASKS:BEGIN phase=4 -->
> 5 tasks. See [CHANGELOG.md](CHANGELOG.md#phase-4-output-enhancements).
<!-- TASKS:END -->

## Phase 5: Documentation & Polish ✅

3 tasks complete — hex.pm metadata, AGENTS.md, comprehensive README examples. See [CHANGELOG.md](CHANGELOG.md#phase-5-documentation--polish).

<!-- TASKS:BEGIN phase=5 -->
> 0 tasks. See [CHANGELOG.md](CHANGELOG.md#phase-5-documentation-polish).
<!-- TASKS:END -->

## Phase 6: Code Health

Static-analysis-driven (`mix reach.*`). Baseline sweep found a clean codebase; the one open task acts on the two surfaced findings.

<!-- TASKS:BEGIN phase=6 -->
| Task | Status | Notes |
|------|--------|-------|
| Task 10 | ⬜ | 🎁 **code_health** · *DialyzerJson* · Run Reach static-analysis sweep and act on findings [D:1/B:2/U:2 → Eff:2.0] 🎯 |
<!-- TASKS:END -->
