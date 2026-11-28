#!/usr/bin/env python3
"""Stage and optionally install Alidade's repo-local skills into Muse (`muse` CLI).

Codex, OpenCode, Hermes, and Antigravity/Gemini read `.agents/skills/` directly,
and Claude Code / Cursor read `.claude/skills/` and `.cursor/skills/` symlinks.
Muse loads plugin bundles via a local marketplace whose `.claude-plugin/plugin.json`
omits Claude-only presentation keys (`author`, `repository`, `keywords`, etc.).

Usage:
    python3 scripts/stage-muse-skills.py --check
    python3 scripts/stage-muse-skills.py --stage
    python3 scripts/stage-muse-skills.py --install
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKILLS_SRC = ROOT / ".agents" / "skills"
STAGING_DEFAULT = ROOT / "build" / "muse-marketplace"
MARKETPLACE_ALIAS = "alidade-local"
PLUGIN_NAME = "alidade-skills"
EXPECTED_SKILLS = ("alidade-ui-design", "alidade-wgpu-viz", "alidade-visual-qa")


def validate_frontmatter(rel: str, text: str, expected_name: str) -> list[str]:
    """Validate YAML frontmatter quoting/syntax with the stdlib only.

    Deliberately small: checks the `---` block exists, every
    `key: value` line is well-formed, the name matches, and plain
    (unquoted) scalar values carry no `: ` mapping separator or
    leading indicator character — an unquoted colon is the failure
    mode that silently corrupts skill frontmatter for strict YAML
    consumers while lenient readers still accept the file.
    """
    errors: list[str] = []
    if not text.startswith("---\n"):
        return [f"{rel}: missing valid YAML frontmatter for {expected_name}"]
    lines = text.splitlines()
    try:
        end = lines.index("---", 1)
    except ValueError:
        return [f"{rel}: unterminated YAML frontmatter for {expected_name}"]
    seen_name = False
    for raw in lines[1:end]:
        if not raw.strip():
            continue
        key, sep, value = raw.partition(":")
        if not sep or not key.strip():
            errors.append(f"{rel}: malformed frontmatter line: {raw!r}")
            continue
        key = key.strip()
        value = value.strip()
        if key == "name" and value == expected_name:
            seen_name = True
        if value.startswith(('"', "'")):
            quote = value[0]
            if len(value) < 2 or not value.endswith(quote):
                errors.append(f"{rel}: unbalanced {quote} quoting for key {key!r}")
        elif ": " in value or value.endswith(":") or value[:1] in "[{|>*&!%@`":
            errors.append(
                f"{rel}: unquoted YAML value for key {key!r} contains reserved "
                "syntax; wrap the value in double quotes"
            )
    if not seen_name:
        errors.append(f"{rel}: missing valid YAML frontmatter for {expected_name}")
    return errors


def validate_sources() -> list[str]:
    errors: list[str] = []
    for name in EXPECTED_SKILLS:
        skill_md = SKILLS_SRC / name / "SKILL.md"
        if not skill_md.is_file():
            errors.append(f"missing canonical skill: {skill_md.relative_to(ROOT)}")
            continue
        text = skill_md.read_text(encoding="utf-8")
        errors.extend(
            validate_frontmatter(str(skill_md.relative_to(ROOT)), text, name)
        )
        for link_root in (".claude/skills", ".cursor/skills"):
            link_path = ROOT / link_root / name
            if not link_path.is_symlink():
                errors.append(f"missing symlink: {link_root}/{name}")
            elif not link_path.resolve().is_dir():
                errors.append(f"broken symlink: {link_root}/{name}")
    return errors


def stage_marketplace(staging_dir: Path) -> Path:
    staging_dir = staging_dir.resolve()
    plugin_dir = staging_dir / "plugins" / PLUGIN_NAME
    if staging_dir.exists():
        shutil.rmtree(staging_dir)
    (plugin_dir / "skills").mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(staging_dir, 0o700)

    for name in EXPECTED_SKILLS:
        shutil.copytree(SKILLS_SRC / name, plugin_dir / "skills" / name)

    # Muse-strict manifest: omit Claude presentation keys (`author`, `repository`, `keywords`)
    plugin_manifest = {
        "name": PLUGIN_NAME,
        "version": "0.1.0",
        "description": "Alidade UI design tokens, wgpu 2D/3D visualization patterns, and two-tier UTM visual QA skills.",
        "skills": ["./skills"],
    }
    manifest_path = plugin_dir / ".claude-plugin" / "plugin.json"
    manifest_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(plugin_manifest, indent=2) + "\n", encoding="utf-8")

    marketplace_manifest = {
        "name": MARKETPLACE_ALIAS,
        "plugins": [
            {
                "name": PLUGIN_NAME,
                "source": f"./plugins/{PLUGIN_NAME}",
                "version": "0.1.0",
                "description": plugin_manifest["description"],
            }
        ],
    }
    mp_path = staging_dir / ".claude-plugin" / "marketplace.json"
    mp_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    mp_path.write_text(json.dumps(marketplace_manifest, indent=2) + "\n", encoding="utf-8")
    return staging_dir


def install_into_muse(staging_dir: Path) -> int:
    muse_bin = shutil.which("muse") or str(Path.home() / ".local" / "bin" / "muse")
    if not Path(muse_bin).is_file():
        print(f"note: muse binary not found at {muse_bin}; staged bundle ready at {staging_dir}")
        return 0
    add = subprocess.run(
        [muse_bin, "plugins", "marketplace", "add", MARKETPLACE_ALIAS, str(staging_dir)],
        capture_output=True,
        text=True,
    )
    if add.returncode != 0 and "already" in (add.stderr + add.stdout).lower():
        subprocess.run(
            [muse_bin, "plugins", "marketplace", "update", MARKETPLACE_ALIAS],
            check=False,
        )
    install = subprocess.run(
        [muse_bin, "plugins", "install", f"{PLUGIN_NAME}@{MARKETPLACE_ALIAS}"],
        capture_output=True,
        text=True,
    )
    if install.returncode != 0 and "already" not in (install.stderr + install.stdout).lower():
        print(install.stderr or install.stdout, file=sys.stderr)
        return install.returncode
    print(f"Installed {PLUGIN_NAME}@{MARKETPLACE_ALIAS} into Muse.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify canonical skills and symlinks")
    parser.add_argument("--stage", action="store_true", help="Build Muse marketplace projection")
    parser.add_argument("--install", action="store_true", help="Stage and install into Muse CLI")
    parser.add_argument("--staging-dir", type=Path, default=STAGING_DEFAULT)
    args = parser.parse_args()

    errors = validate_sources()
    if errors:
        for err in errors:
            print(f"ERROR: {err}", file=sys.stderr)
        return 1

    if args.stage or args.install:
        staged = stage_marketplace(args.staging_dir)
        print(f"Staged Muse-compatible marketplace at {staged}")
        if args.install:
            return install_into_muse(staged)
    else:
        print(f"OK: {len(EXPECTED_SKILLS)} canonical Alidade skills and agent symlinks verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
