#!/usr/bin/env python3
"""
Process EVE Online Neocom icons for Mimir app.

Downloads authentic Neocom icons from eve_reference/ and generates:
- Navigation icons (32x32) for assets/icons/eve/
- Tray icons (16x16 and 32x32) in template mode for assets/icons/tray/

Template mode: Black pixels with alpha channel for macOS system tray
"""

from PIL import Image
import os
from pathlib import Path


# Icon mappings: (reference_filename, output_name)
ICON_MAPPINGS = [
    ('scopenetwork.png', 'dashboard.png'),
    ('skills.png', 'skills.png'),
    ('wallet.png', 'wallet.png'),
    ('character_sheet.png', 'characters.png'),
    ('settings.png', 'settings.png'),
    ('help.png', 'tutorial.png'),
]

# Paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
REFERENCE_DIR = PROJECT_ROOT / 'assets' / 'icons' / 'eve_reference'
EVE_DIR = PROJECT_ROOT / 'assets' / 'icons' / 'eve'
TRAY_DIR = PROJECT_ROOT / 'assets' / 'icons' / 'tray'


def convert_to_template_mode(img):
    """
    Convert RGBA image to template mode (black with alpha).

    Template mode icons are pure black (0,0,0) with varying alpha.
    macOS system tray will apply system colors to these icons.
    """
    # Convert to RGBA if not already
    if img.mode != 'RGBA':
        img = img.convert('RGBA')

    # Get pixel data
    pixels = img.load()
    width, height = img.size

    # Convert each pixel to black but preserve alpha
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            # Set RGB to black, keep alpha
            pixels[x, y] = (0, 0, 0, a)

    return img


def process_navigation_icon(source_path, output_name):
    """Generate 32x32 navigation icon."""
    img = Image.open(source_path)

    # Resize to 32x32 with high-quality resampling
    nav_icon = img.resize((32, 32), Image.Resampling.LANCZOS)

    # Save to eve directory
    output_path = EVE_DIR / output_name
    nav_icon.save(output_path)
    print(f"  ✓ Navigation: {output_name} (32x32)")


def process_tray_icons(source_path, output_name):
    """Generate 16x16 and 32x32 template mode tray icons."""
    img = Image.open(source_path)

    # Generate 16x16 (1x)
    tray_1x = img.resize((16, 16), Image.Resampling.LANCZOS)
    tray_1x = convert_to_template_mode(tray_1x)
    output_1x = TRAY_DIR / output_name
    tray_1x.save(output_1x)
    print(f"  ✓ Tray 1x: {output_name} (16x16)")

    # Generate 32x32 (2x)
    tray_2x = img.resize((32, 32), Image.Resampling.LANCZOS)
    tray_2x = convert_to_template_mode(tray_2x)
    output_2x = TRAY_DIR / output_name.replace('.png', '@2x.png')
    tray_2x.save(output_2x)
    print(f"  ✓ Tray 2x: {output_name.replace('.png', '@2x.png')} (32x32)")


def main():
    """Process all Neocom icons."""
    print("Mimir Neocom Icon Processor")
    print("=" * 60)
    print(f"Source: {REFERENCE_DIR}")
    print(f"Output: {EVE_DIR} (navigation) + {TRAY_DIR} (tray)")
    print()

    # Verify source directory exists
    if not REFERENCE_DIR.exists():
        print(f"❌ Error: Source directory not found: {REFERENCE_DIR}")
        return

    # Create output directories if needed
    EVE_DIR.mkdir(parents=True, exist_ok=True)
    TRAY_DIR.mkdir(parents=True, exist_ok=True)

    # Process each icon
    for ref_filename, output_name in ICON_MAPPINGS:
        source_path = REFERENCE_DIR / ref_filename

        if not source_path.exists():
            print(f"⚠️  Skipping {ref_filename}: file not found")
            continue

        print(f"Processing {ref_filename} → {output_name}")

        # Generate navigation icon
        process_navigation_icon(source_path, output_name)

        # Generate tray icons
        process_tray_icons(source_path, output_name)

        print()

    print("=" * 60)
    print("✓ All icons processed successfully!")
    print()
    print("Generated:")
    print(f"  - 6 navigation icons (32x32) in {EVE_DIR}")
    print(f"  - 12 tray icons (16x16 + 32x32) in {TRAY_DIR}")
    print()
    print("Next: Run 'flutter run -d macos' to verify icons in app")


if __name__ == "__main__":
    main()
