# UX polish plan — 23 Mar 2026

## Revert checkpoint

Current pre-polish snapshot saved under:

- `.snapshots/2026-03-23-pre-ux-polish/`

This is a manual rollback point since the workspace is not a git repository.

## Goals

1. Preserve the stronger visual language already introduced in `dashboard`, `meals`, and `supplies`.
2. Bring older screens up to the same standard.
3. Reduce cognitive load and improve task hierarchy.
4. Make owner/manager workflows clearer.

## Phase 1 — low-risk consistency pass

### 1. Kids screen
- add a top summary hero card
- show daily readiness progress at screen level
- refresh child cards with better metadata grouping
- improve add-child sheet styling and CTA hierarchy

### 2. Staff screen
- unify section headers with newer design
- tighten profile/status hierarchy
- improve manager task card presentation
- make owner actions more explicit

### 3. Laundry screen
- refine top quick-stat area
- improve spacing rhythm in stats/history
- strengthen section labels and empty/loading states

## Phase 2 — higher impact product UX

### Dashboard
- reduce competing emphasis
- strengthen urgent vs informational content
- simplify actionable rows

### Supplies + Gas
- tighten vertical hierarchy
- separate primary supplier from backup supplier more clearly
- add owner-payment helper text after supplier confirmation

## Phase 3 — systemization

- shared page intro/header pattern
- shared status/alert card pattern
- shared top summary strip pattern
- shared modal sheet header pattern

## Success criteria

- each main tab has one clear visual anchor near the top
- screens feel consistent in spacing, section headers, and card treatment
- actions are clearer by role
- no analyzer issues
- app still builds and runs on emulator
