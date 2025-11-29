#!/usr/bin/env python3
"""
Generate final Mimir icon set - Purple Eye in tray-icon style.

Creates clean, outline-only eye icons matching the tray icon design.
"""

from PIL import Image, ImageDraw, ImageFilter
import math


# Purple color scheme
PURPLE = (155, 109, 255)      # #9B6DFF
PURPLE_DARK = (120, 80, 200)
PURPLE_LIGHT = (200, 170, 255)
BLACK = (0, 0, 0)


def create_radial_gradient(size, center_color, edge_color, radius_factor=1.0):
    """Create a circular radial gradient."""
    width, height = size
    center_x, center_y = width // 2, height // 2
    max_radius = min(width, height) // 2 * radius_factor

    image = Image.new('RGBA', size, (0, 0, 0, 0))
    pixels = image.load()

    for y in range(height):
        for x in range(width):
            # Distance from center
            dx = x - center_x
            dy = y - center_y
            distance = math.sqrt(dx * dx + dy * dy)

            # Calculate interpolation factor
            if distance > max_radius:
                ratio = 1.0
            else:
                ratio = distance / max_radius

            # Interpolate colors
            r = int(center_color[0] * (1 - ratio) + edge_color[0] * ratio)
            g = int(center_color[1] * (1 - ratio) + edge_color[1] * ratio)
            b = int(center_color[2] * (1 - ratio) + edge_color[2] * ratio)

            # Alpha based on distance (fade out at edges)
            alpha = 255 if distance <= max_radius else 0

            pixels[x, y] = (r, g, b, alpha)

    return image


def draw_eye_tray_style(size, color=None, is_template=False):
    """
    Draw eye icon in clean tray-icon style.

    Args:
        size: Icon size in pixels
        color: RGB tuple for colored version (or None for template)
        is_template: If True, draw in black for template mode
    """
    # Start with transparent background
    base_image = Image.new('RGBA', (size, size), (0, 0, 0, 0))

    center_x = size // 2
    center_y = size // 2

    if is_template:
        # Template mode: black with alpha - draw directly
        draw = ImageDraw.Draw(base_image)
        stroke_color = BLACK
    else:
        # Colored mode: create glow layer first
        glow_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        glow = create_radial_gradient(
            (size, size),
            (color[0], color[1], color[2], 40),
            (color[0], color[1], color[2], 0),
            radius_factor=0.5
        )
        base_image = Image.alpha_composite(base_image, glow)

        # Now draw eye on top of glow
        draw = ImageDraw.Draw(base_image)
        stroke_color = color

    # Elliptical eye outline (almond shape)
    eye_width = int(size * 0.7)
    eye_height = int(size * 0.35)
    stroke = max(2, size // 20)

    # Eye outline bounding box
    eye_bbox = [
        center_x - eye_width // 2,
        center_y - eye_height // 2,
        center_x + eye_width // 2,
        center_y + eye_height // 2
    ]

    # Draw complete ellipse outline (not filled)
    draw.ellipse(eye_bbox, outline=stroke_color, width=stroke)

    # Iris circle (outline)
    iris_radius = int(size * 0.18)
    iris_stroke = max(2, size // 25)
    iris_bbox = [
        center_x - iris_radius,
        center_y - iris_radius,
        center_x + iris_radius,
        center_y + iris_radius
    ]
    draw.ellipse(iris_bbox, outline=stroke_color, width=iris_stroke)

    # Pupil (filled)
    pupil_radius = int(size * 0.08)
    pupil_bbox = [
        center_x - pupil_radius,
        center_y - pupil_radius,
        center_x + pupil_radius,
        center_y + pupil_radius
    ]

    if is_template:
        draw.ellipse(pupil_bbox, fill=stroke_color)
    else:
        # In colored mode, fill pupil with dark version of color for contrast
        pupil_color = PURPLE_DARK
        draw.ellipse(pupil_bbox, fill=pupil_color)

    return base_image


def generate_icon_set():
    """Generate complete icon set for Mimir app."""
    print("Mimir Final Icon Generator")
    print("=" * 60)
    print("Generating Purple Eye icon set (tray-icon style)")
    print()

    # macOS app icon sizes
    app_sizes = [16, 32, 64, 128, 256, 512, 1024]

    # Generate app icons in purple
    print("Generating macOS app icons...")
    for size in app_sizes:
        icon = draw_eye_tray_style(size, color=PURPLE, is_template=False)
        filename = f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png"
        icon.save(filename)
        print(f"  ✓ app_icon_{size}.png")

    print()

    # Generate tray icons (template mode)
    print("Generating system tray icons...")

    tray_22 = draw_eye_tray_style(22, is_template=True)
    tray_22.save("assets/icons/eve/app_icon.png")
    print("  ✓ app_icon.png (22x22, template mode)")

    tray_44 = draw_eye_tray_style(44, is_template=True)
    tray_44.save("assets/icons/eve/app_icon@2x.png")
    print("  ✓ app_icon@2x.png (44x44, template mode)")

    print()
    print("=" * 60)
    print("✓ Final icon set generated!")
    print()
    print("Files created:")
    print("  - macOS app icons: macos/.../AppIcon.appiconset/app_icon_*.png")
    print("  - System tray: assets/icons/eve/app_icon.png + @2x")


if __name__ == "__main__":
    generate_icon_set()
