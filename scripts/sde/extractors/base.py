"""Base extractor class for SDE data types."""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass
class ExtractionResult:
    """Result from an extractor."""

    filename: str
    data: dict[str, Any]
    item_count: int


class BaseExtractor(ABC):
    """Base class for SDE data extractors.

    To create a new extractor:
    1. Inherit from this class
    2. Set `name` and `output_filename` class attributes
    3. Implement the `extract()` method

    Example:
        class ShipsExtractor(BaseExtractor):
            name = "ships"
            output_filename = "ships.json"

            def extract(self, sde_path: Path) -> ExtractionResult:
                # Parse SDE files and return extracted data
                ...
    """

    name: str
    output_filename: str

    @abstractmethod
    def extract(self, sde_path: Path) -> ExtractionResult:
        """Extract data from SDE files.

        Args:
            sde_path: Path to extracted SDE directory

        Returns:
            ExtractionResult with filename, data dict, and item count
        """
        pass
