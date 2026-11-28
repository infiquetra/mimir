"""SDE data extractors.

Each extractor handles a specific type of EVE Online static data.
To add a new data type:
1. Create a new extractor class inheriting from BaseExtractor
2. Implement the extract() method
3. Register it in EXTRACTORS dict below
"""

from .base import BaseExtractor
from .skills import SkillsExtractor

# Registry of all available extractors.
# Add new extractors here as features require more SDE data.
EXTRACTORS: dict[str, type[BaseExtractor]] = {
    "skills": SkillsExtractor,
    # Future extractors:
    # "ships": ShipsExtractor,
    # "modules": ModulesExtractor,
    # "blueprints": BlueprintsExtractor,
}

__all__ = ["BaseExtractor", "SkillsExtractor", "EXTRACTORS"]
