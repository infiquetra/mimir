# Alidade Development Skills (`infiquetra/mimir`)

Single-source development skills for **Alidade**, compatible across **Muse (`muse` / Maki)**, **Claude Code**, **OpenAI Codex**, **OpenCode**, **Cursor Agent**, **Hermes**, and **Antigravity / Gemini**:

- **Codex, OpenCode, Hermes & Gemini** read canonical skills directly from `.agents/skills/<name>/SKILL.md`.
- **Claude Code** resolves `.claude/skills/<name>` symlinks to `.agents/skills/<name>`.
- **Cursor Agent** resolves `.cursor/skills/<name>` symlinks to `.agents/skills/<name>`.
- **Muse (`muse` CLI)** reads `AGENTS.md` automatically on startup **and** can install these skills as native `/alidade-*` plugin shortcuts via `python3 scripts/stage-muse-skills.py --install` (which projects `.agents/skills/` into `build/muse-marketplace/` with Muse-strict `.claude-plugin/plugin.json` metadata).

| Skill | Purpose |
| --- | --- |
| [`alidade-ui-design`](./skills/alidade-ui-design/SKILL.md) | Astrometric dark `DesignTokens` (adapted from Google Frontend Design + Rerun `re_ui`), HTML/Canvas prototype gate, 3-size body typography with tabular numerals, `egui_tiles` workspace panes, and anti-clutter rules. |
| [`alidade-wgpu-viz`](./skills/alidade-wgpu-viz/SKILL.md) | `egui 0.37` + `eframe wgpu` (Metal) spatial/flow rendering: `petgraph` + `dagre` + `egui-snarl` + `kurbo`/`lyon` Sankey-DAG pipelines, instanced 120 fps 2D/3D star maps (`egui_wgpu::CallbackTrait` + `kiddo`), radial fitting wheels, and WGSL polar application shaders. |
| [`alidade-visual-qa`](./skills/alidade-visual-qa/SKILL.md) | Two-tier visual & accessibility verification: headless `egui_kittest` snapshot + AccessKit label gates in host CI, and locked SSH visual testing inside the `macos-test-02` UTM guest (`axcli` + `cliclick` + `screencapture`). |
