# Archive - Shipped + Rejected + Superseded Items

> **Terminal history for queued, learning, and decision items.** When something
> from `QUEUED.md` ships, move it here as SHIPPED. When something is consciously
> rejected, move it here as REJECTED. When a learning or decision is invalidated,
> move the pre-correction version here as SUPERSEDED.
>
> Append newest entries to the top. Preserve history; never silently delete.

---

### SHIPPED 2026-09-11: Skill cycle-time bonuses (Rapid Firing, Gunnery, MLO, Rapid Launch, XL specs, missile specialisations)

**Author.** Antigravity / Lead Orchestrator
**Shipped as.** Published skill-owned dogma modifiers routed through DogmaEngine:
Gunnery (effect 414, attr 441, -2%/lvl), Rapid Firing (effect 582, attr 293, -4%/lvl),
MLO & Rapid Launch (effect 1763, attr 293, -2% and -3%/lvl), XL Torpedo & Cruise Spec
(effects 6578/6577, attr 293, -2%/lvl), plus a curated Effect1851 fallback for the
six sub-capital missile specialisations. Multiplicative, unpenalized (owner is skill),
volley unchanged, six-slot direct filter `{182, 183, 184, 1285, 1289, 1290}`, and weapon
cap drain duration falls back to rateOfFire so capacitor stability updates.
**Refs.** LEARNINGS 2026-09-11; DECISIONS 2026-09-11; `.agents/plans/2026-09-11-fitting-completion-skill-rof-and-fighters.md`.

### SHIPPED 2026-09-11: Fighter support (fighter bay, launch tubes, squadron DPS, ability selection, StatsPanel UI)

**Author.** Antigravity / Lead Orchestrator
**Shipped as.** Complete fighter modeling across all layers:
`FighterGroup`, `FighterSquadronStats`, `FighterAbilityKind` Freezed models; EFT parser
distinguishing category 18 (drones) and 87 (fighters) with quantity summing; combat
snapshot and killmail mappers for FighterBay (158) and tubes (159..163); ESI export;
DogmaEngine classification (attr 2215), squadron counts with remainders, launch tube
and class caps (light/support/heavy) enforced in declaration order; Attack (6465) and
missile fallback ability DPS calculation normalized from millisecond durations (attr 2233);
DDA (6556) and FSU (6566) stacking penalties; carrier hull bonus scaling via attribute 280;
StatsPanel OFFENSE row and dynamic `FIGHTERS` section with bay over-capacity error styling.
**Refs.** LEARNINGS 2026-09-11; DECISIONS 2026-09-11; `.agents/plans/2026-09-11-fitting-completion-skill-rof-and-fighters.md`.

### SUPERSEDED 2026-09-11: modifierInfo stops at item boundaries: skill-to-module bonuses are pyfa-hardcoded (2026-09-08)

**Author.** Qwen Code (superseded by Antigravity / Architect 2026-09-11)
**Original premise.** "The SDE's modifierInfo does not publish skill cycle bonuses as
resolvable modifiers... pyfa implements the cross-item part with hardcoded handlers...
derived rules fail."
**Why superseded.** The premise was an artifact of SDE extraction: Category 16 (Skill)
was simply excluded from `generate_dogma_sde.py`'s `TARGET_CATEGORIES`. Once bundled,
CCP's published `LocationRequiredSkillModifier` on skill types resolve directly. Only
effect 1851 (six sub-cap missile specs) and damage effects 660–668/1730 publish empty
modifier lists; all other skill cycle bonuses resolve natively from data.
**Refs.** LEARNINGS 2026-09-11; DECISIONS 2026-09-11.

### SHIPPED 2026-09-08: Cap injectors in the cap simulation

**Author.** Qwen Code
**Shipped as.** CapSimulator injectors ported from pyfa capSim: boosters are
postponed while their gain would overshoot capacity, fire on demand when a
drain cannot be paid, and top the capacitor up after spending; the stability
wrap check now also compares the postponed-injector set. DogmaEngine collects
injectors from fitted cap booster charges (capacitorBonus 67) and adds the
reactivation delay (1795) to every module cycle, like pyfa. Clips are
infinite because fittings carry no charge quantities; reload accounting
remains queued (P3).
**Refs.** LEARNINGS 2026-09-08 cap-injector entry; QUEUED clip reloads.

### SHIPPED 2026-09-08: Drone DPS and drone-domain bonuses

**Author.** Qwen Code
**Shipped as.** Drone pass in DogmaEngine: active drones = in-space count or
fitted count (pyfa-style), capped by ship drone bandwidth (attribute 1272 per
drone); volley = damage components times the drone's damage modifier after
charID-domain bonuses; bay usage from the newly bundled volume attribute 38.
Drone damage amplifiers apply raw, filtered to drones requiring the linked
skill (pyfa Effect6556). Panel gained DRONES bandwidth/bay rows and a Drones
DPS row. Fighters remain queued (P3).
**Refs.** LEARNINGS 2026-09-08 skill-filter entry; QUEUED fighter support.

### SHIPPED 2026-09-08: Model dogma expression trees for bonuses ESI hides

**Author.** Qwen Code
**Shipped as.** Propulsion speed bonuses (effects 6730/6731) via a curated,
cross-checked map (2026-09-07); turret/missile DPS, volley, optimal and
falloff via the SDE's resolved `dgmEffects.modifierInfo` bundled as
`assets/sde/effect_modifiers.json` (2026-09-08). The expression-tree evaluator
itself was never built: `dgmExpressions` is retired in the SDE and the
resolved modifier list supersedes it, skill linkage and group restrictions
included.
**Refs.** LEARNINGS 2026-09-08 modifierInfo entry; DECISIONS 2026-09-08
bundled-modifiers entry.

<!-- First archived entry goes above this line. Keep newest-first. -->
