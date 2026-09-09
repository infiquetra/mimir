# Archive - Shipped + Rejected + Superseded Items

> **Terminal history for queued, learning, and decision items.** When something
> from `QUEUED.md` ships, move it here as SHIPPED. When something is consciously
> rejected, move it here as REJECTED. When a learning or decision is invalidated,
> move the pre-correction version here as SUPERSEDED.
>
> Append newest entries to the top. Preserve history; never silently delete.

---

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
