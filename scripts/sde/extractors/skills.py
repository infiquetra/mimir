"""Skills extractor for EVE Online SDE.

Extracts skill data including:
- Skill type IDs and names
- Skill groups (Gunnery, Missiles, etc.)
- Skill category information
"""

from pathlib import Path
from typing import Any

import yaml

from .base import BaseExtractor, ExtractionResult

# EVE Online category ID for skills
SKILL_CATEGORY_ID = 16


class SkillsExtractor(BaseExtractor):
    """Extracts skill data from EVE Online SDE."""

    name = "skills"
    output_filename = "skills.json"

    def extract(self, sde_path: Path) -> ExtractionResult:
        """Extract skills from SDE files.

        Parses typeIDs.yaml, groupIDs.yaml, and categoryIDs.yaml to build
        a complete skills dataset with groups and categories.

        Args:
            sde_path: Path to extracted SDE directory

        Returns:
            ExtractionResult with skills data
        """
        # Load SDE YAML files
        type_ids = self._load_yaml(sde_path / "fsd" / "typeIDs.yaml")
        group_ids = self._load_yaml(sde_path / "fsd" / "groupIDs.yaml")
        category_ids = self._load_yaml(sde_path / "fsd" / "categoryIDs.yaml")

        # Extract skill groups (groups with categoryID = 16)
        skill_groups = self._extract_skill_groups(group_ids)
        skill_group_ids = set(skill_groups.keys())

        # Extract skills (types belonging to skill groups)
        skills = self._extract_skills(type_ids, skill_group_ids)

        # Build output structure
        data = {
            "categories": [
                {
                    "categoryId": SKILL_CATEGORY_ID,
                    "categoryName": category_ids.get(SKILL_CATEGORY_ID, {})
                    .get("name", {})
                    .get("en", "Skill"),
                }
            ],
            "groups": [
                {
                    "groupId": gid,
                    "groupName": gdata["name"],
                    "categoryId": SKILL_CATEGORY_ID,
                }
                for gid, gdata in sorted(skill_groups.items())
            ],
            "skills": skills,
        }

        return ExtractionResult(
            filename=self.output_filename,
            data=data,
            item_count=len(skills),
        )

    def _load_yaml(self, path: Path) -> dict[int, Any]:
        """Load a YAML file from the SDE."""
        with open(path, encoding="utf-8") as f:
            return yaml.safe_load(f) or {}

    def _extract_skill_groups(
        self, group_ids: dict[int, Any]
    ) -> dict[int, dict[str, Any]]:
        """Extract groups that belong to the Skill category."""
        skill_groups = {}
        for group_id, group_data in group_ids.items():
            if group_data.get("categoryID") == SKILL_CATEGORY_ID:
                skill_groups[group_id] = {
                    "name": group_data.get("name", {}).get("en", f"Group {group_id}"),
                }
        return skill_groups

    def _extract_skills(
        self, type_ids: dict[int, Any], skill_group_ids: set[int]
    ) -> list[dict[str, Any]]:
        """Extract skill types from typeIDs."""
        skills = []
        for type_id, type_data in type_ids.items():
            group_id = type_data.get("groupID")
            if group_id in skill_group_ids and type_data.get("published", False):
                skills.append(
                    {
                        "typeId": type_id,
                        "typeName": type_data.get("name", {}).get(
                            "en", f"Skill {type_id}"
                        ),
                        "groupId": group_id,
                    }
                )

        # Sort by type ID for consistent output
        return sorted(skills, key=lambda s: s["typeId"])
