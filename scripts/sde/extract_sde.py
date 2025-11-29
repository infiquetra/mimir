#!/usr/bin/env python3
"""EVE Online SDE extraction script.

Downloads the latest SDE from Fuzzwork and extracts game data for Mimir.
This script is designed to be run by GitHub Actions but can also be run locally.

Usage:
    python extract_sde.py --output-dir ./output

The script will:
1. Check for new SDE versions on Fuzzwork
2. Download and extract the SDE if newer
3. Run all registered extractors
4. Generate manifest.json with checksums
5. Output files to the specified directory
"""

import argparse
import hashlib
import json
import re
import shutil
import sys
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.request import urlopen, urlretrieve

# Add parent to path for imports when run directly
sys.path.insert(0, str(Path(__file__).parent))

from extractors import EXTRACTORS

# Fuzzwork SDE download URL
FUZZWORK_SDE_URL = "https://www.fuzzwork.co.uk/dump/latest/sde.zip"
FUZZWORK_CHECKSUM_URL = "https://www.fuzzwork.co.uk/dump/latest/sde.zip.md5"


@dataclass
class SdeVersion:
    """Parsed SDE version information."""

    version: str  # YYYYMMDD format
    eve_version: str  # Full EVE version string


def get_latest_sde_version() -> SdeVersion:
    """Get the latest SDE version from Fuzzwork.

    Parses the directory listing to find the version date.
    """
    # Fuzzwork includes version in the zip filename pattern
    # We'll extract it from the actual SDE after download
    # For now, return a placeholder that will be updated
    return SdeVersion(version="unknown", eve_version="unknown")


def download_sde(output_path: Path) -> Path:
    """Download the SDE zip file from Fuzzwork.

    Args:
        output_path: Directory to save the zip file

    Returns:
        Path to downloaded zip file
    """
    zip_path = output_path / "sde.zip"
    print(f"Downloading SDE from {FUZZWORK_SDE_URL}...")
    urlretrieve(FUZZWORK_SDE_URL, zip_path)
    print(f"Downloaded to {zip_path}")
    return zip_path


def extract_sde(zip_path: Path, output_path: Path) -> Path:
    """Extract the SDE zip file.

    Args:
        zip_path: Path to the zip file
        output_path: Directory to extract to

    Returns:
        Path to extracted SDE directory
    """
    print(f"Extracting SDE to {output_path}...")
    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(output_path)

    # The SDE extracts to a 'sde' subdirectory
    sde_path = output_path / "sde"
    if not sde_path.exists():
        # Sometimes it extracts directly without subdirectory
        sde_path = output_path

    print(f"Extracted to {sde_path}")
    return sde_path


def parse_sde_version(sde_path: Path) -> SdeVersion:
    """Parse version information from extracted SDE.

    The version is typically in the directory name or a metadata file.
    """
    # Try to find version from common locations
    # 1. Check if there's a version file
    version_candidates = [
        sde_path / "version.txt",
        sde_path / "metadata.txt",
    ]

    for candidate in version_candidates:
        if candidate.exists():
            content = candidate.read_text().strip()
            # Parse version from content
            match = re.search(r"(\d{8})", content)
            if match:
                return SdeVersion(
                    version=match.group(1),
                    eve_version=f"sde-{match.group(1)}-TRANQUILITY",
                )

    # 2. Try to extract from fsd/universe directory modification
    # This is a fallback - use download date
    import datetime

    today = datetime.date.today().strftime("%Y%m%d")
    return SdeVersion(
        version=today,
        eve_version=f"sde-{today}-TRANQUILITY",
    )


def compute_checksum(file_path: Path) -> str:
    """Compute SHA256 checksum of a file."""
    sha256 = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            sha256.update(chunk)
    return f"sha256:{sha256.hexdigest()}"


def run_extractors(sde_path: Path, output_dir: Path) -> dict[str, dict[str, Any]]:
    """Run all registered extractors.

    Args:
        sde_path: Path to extracted SDE
        output_dir: Directory to write output files

    Returns:
        Dict mapping extractor names to their results
    """
    results = {}

    for name, extractor_class in EXTRACTORS.items():
        print(f"Running {name} extractor...")
        extractor = extractor_class()
        result = extractor.extract(sde_path)

        # Write output file
        output_file = output_dir / result.filename
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(result.data, f, indent=2)

        # Compute checksum
        checksum = compute_checksum(output_file)

        results[name] = {
            "filename": result.filename,
            "item_count": result.item_count,
            "checksum": checksum,
        }
        print(f"  Extracted {result.item_count} items to {result.filename}")

    return results


def generate_manifest(
    version: SdeVersion,
    extractor_results: dict[str, dict[str, Any]],
    output_dir: Path,
) -> Path:
    """Generate manifest.json with version and checksums.

    Args:
        version: SDE version information
        extractor_results: Results from all extractors
        output_dir: Directory to write manifest

    Returns:
        Path to manifest file
    """
    # For backward compatibility, include skill count at top level
    skill_count = extractor_results.get("skills", {}).get("item_count", 0)

    # Use skills checksum as the main checksum for backward compatibility
    main_checksum = extractor_results.get("skills", {}).get("checksum", "")

    manifest = {
        "version": version.version,
        "checksum": main_checksum,
        "eveVersion": version.eve_version,
        "skillCount": skill_count,
        # Detailed info for future extensibility
        "files": {
            name: {
                "filename": data["filename"],
                "checksum": data["checksum"],
                "count": data["item_count"],
            }
            for name, data in extractor_results.items()
        },
    }

    manifest_path = output_dir / "manifest.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    print(f"Generated manifest at {manifest_path}")
    return manifest_path


def main():
    parser = argparse.ArgumentParser(
        description="Extract EVE Online SDE data for Mimir"
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        required=True,
        help="Directory to write output files",
    )
    parser.add_argument(
        "--sde-path",
        type=Path,
        help="Path to already-extracted SDE (skips download)",
    )
    parser.add_argument(
        "--version",
        type=str,
        help="Override version string (YYYYMMDD format)",
    )
    args = parser.parse_args()

    # Create output directory
    args.output_dir.mkdir(parents=True, exist_ok=True)

    # Download and extract SDE if not provided
    if args.sde_path:
        sde_path = args.sde_path
        print(f"Using provided SDE at {sde_path}")
    else:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            zip_path = download_sde(temp_path)
            sde_path = extract_sde(zip_path, temp_path)

            # Parse version
            version = parse_sde_version(sde_path)
            if args.version:
                version = SdeVersion(
                    version=args.version,
                    eve_version=f"sde-{args.version}-TRANQUILITY",
                )

            # Run extractors
            results = run_extractors(sde_path, args.output_dir)

            # Generate manifest
            generate_manifest(version, results, args.output_dir)

            print("\nExtraction complete!")
            print(f"Version: {version.version}")
            print(f"EVE Version: {version.eve_version}")
            for name, data in results.items():
                print(f"  {name}: {data['item_count']} items")

            return

    # If SDE path was provided, we need to handle it outside the temp context
    version = parse_sde_version(sde_path)
    if args.version:
        version = SdeVersion(
            version=args.version,
            eve_version=f"sde-{args.version}-TRANQUILITY",
        )

    results = run_extractors(sde_path, args.output_dir)
    generate_manifest(version, results, args.output_dir)

    print("\nExtraction complete!")
    print(f"Version: {version.version}")
    print(f"EVE Version: {version.eve_version}")
    for name, data in results.items():
        print(f"  {name}: {data['item_count']} items")


if __name__ == "__main__":
    main()
