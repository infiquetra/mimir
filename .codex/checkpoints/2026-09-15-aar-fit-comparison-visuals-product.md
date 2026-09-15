# AAR fit comparison visuals — Product checkpoint

Date: 2026-09-15

Baseline: `develop` at `d1114f7`

Branch: `chore/aar-fit-comparison-visuals-spec`

## Delivered

[Canonical specification](../../docs/specs/aar-fit-comparison-visuals.md): six user
workflows, 30 acceptance criteria and 46 concrete domain/provider/UI test cases.
README and engineering-journal links/status updated; the feature remains queued.

## Decisions to preserve

- Separate immutable source snapshots for fight/current/victim/proposed fits;
  generation fit bound to actual prepared input, legacy missing history disclosed.
- Read-only workspace with common skills/damage profile, deterministic duplicate
  matching and explicit source/completeness. No editor or evidence mutation on view.
- Validated optional full candidates and saved/EFT reference workflows; client
  owns baseline association. Structural rejection differs from resource warnings.
- Changes BOM is an informational net inventory diff; Full replacement credits
  no baseline. Incomplete baselines cannot yield a complete change list.
- ESI average prices are cached estimates; availability is qualified cached stock.
  Unknown loaded quantities remain unquantified; sustained repair Not modeled.

## Verification

Independent source/history and stat/diff/BOM reviews passed with all findings
resolved. Checked numerical BOM/EHP fixtures, 30-criterion traceability, all 46
case IDs, Markdown tables and local links. No Flutter runtime suites ran because
this delivery changes only documentation/tracking.

The initial oversized patch hit the Hermes hook's 64 KiB input bound. Read its
skill/hook and corrected request size using smaller patches through the same
guarded tool; no profile mutation or external dialogue was needed.

## Next

Plan/Test-Author prepare architecture, implementation estimates and RED/GREEN
ownership. Keep the roadmap entry queued through implementation and verification.
The prior fit import/capture initiative is already shipped at this baseline.
Preserve unrelated untracked `.claude/saga/` and `.hermes/` content.
