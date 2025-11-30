#!/usr/bin/env python3
"""
Generate Mimir icon concepts for macOS app and system tray.

Creates 2 design concepts in 4 color schemes:
1. The Eye (Odin's Eye) - Proper almond-shaped eye
2. The Well/Portal - Concentric rings

Color schemes: Teal, Orange (EVE), Blue, Purple

Each concept generates:
- 512x512 full-color app icons (4 colors each)
- 22x22 + 44x44 template mode tray icons (black with alpha)
"""

from PIL import Image, ImageDraw, ImageFilter
import math


# Color schemes
COLOR_SCHEMES = {
    'teal': {
        'primary': (0, 212, 170),      # #00D4AA
        'dark': (0, 170, 136),
        'light': (102, 235, 211),
    },
    'orange': {
        'primary': (232, 166, 40),     # #E8A628
        'dark': (190, 135, 30),
        'light': (255, 200, 100),
    },
    'blue': {
        'primary': (74, 158, 255),     # #4A9EFF
        'dark': (50, 120, 200),
        'light': (150, 200, 255),
    },
    'purple': {
        'primary': (155, 109, 255),    # #9B6DFF
        'dark': (120, 80, 200),
        'light': (200, 170, 255),
    },
}

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


def draw_eye_icon(size, color_scheme=None, is_template=False):
    """
    Draw The Eye (Odin's Eye) - proper almond-shaped eye.

    Args:
        size: Icon size in pixels
        color_scheme: Dict with 'primary', 'dark', 'light' colors (or None for template)
        is_template: If True, draw in black for template mode
    """
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    center_x = size // 2
    center_y = size // 2

    if is_template:
        # Template mode: black with alpha
        color = BLACK

        # Almond-shaped eye outline using ellipse segments
        eye_width = int(size * 0.7)
        eye_height = int(size * 0.35)

        # Draw top half of eye (arc)
        eye_bbox = [
            center_x - eye_width // 2,
            center_y - eye_height // 2,
            center_x + eye_width // 2,
            center_y + eye_height // 2
        ]
        draw.arc(eye_bbox, start=0, end=180, fill=color, width=max(2, size // 20))

        # Draw bottom half of eye (arc)
        draw.arc(eye_bbox, start=180, end=360, fill=color, width=max(2, size // 20))

        # Iris circle
        iris_radius = int(size * 0.18)
        iris_bbox = [
            center_x - iris_radius,
            center_y - iris_radius,
            center_x + iris_radius,
            center_y + iris_radius
        ]
        draw.ellipse(iris_bbox, outline=color, width=max(2, size // 25))

        # Pupil (filled)
        pupil_radius = int(size * 0.08)
        pupil_bbox = [
            center_x - pupil_radius,
            center_y - pupil_radius,
            center_x + pupil_radius,
            center_y + pupil_radius
        ]
        draw.ellipse(pupil_bbox, fill=color)

    else:
        # Full color mode with gradients
        colors = color_scheme
        primary = colors['primary']
        dark = colors['dark']
        light = colors['light']

        # Subtle outer glow
        glow = create_radial_gradient(
            (size, size),
            light + (80,),
            primary + (0,),
            radius_factor=0.5
        )
        image = Image.alpha_composite(image, glow)

        # Almond-shaped eye outline
        eye_width = int(size * 0.7)
        eye_height = int(size * 0.35)
        stroke = size // 20

        # Create eye shape with ellipse
        eye_bbox = [
            center_x - eye_width // 2,
            center_y - eye_height // 2,
            center_x + eye_width // 2,
            center_y + eye_height // 2
        ]

        # Draw outline
        draw.ellipse(eye_bbox, outline=primary, width=stroke)

        # Iris with gradient (larger filled circle)
        iris_radius = int(size * 0.2)
        iris_img = create_radial_gradient(
            (iris_radius * 2, iris_radius * 2),
            light,
            dark,
            radius_factor=1.0
        )
        image.paste(
            iris_img,
            (center_x - iris_radius, center_y - iris_radius),
            iris_img
        )

        # Iris ring outline
        iris_bbox = [
            center_x - iris_radius,
            center_y - iris_radius,
            center_x + iris_radius,
            center_y + iris_radius
        ]
        draw.ellipse(iris_bbox, outline=primary, width=stroke // 2)

        # Pupil (dark center with slight highlight)
        pupil_radius = int(size * 0.08)
        pupil_bbox = [
            center_x - pupil_radius,
            center_y - pupil_radius,
            center_x + pupil_radius,
            center_y + pupil_radius
        ]

        # Create pupil with gradient (dark to very dark)
        pupil_img = create_radial_gradient(
            (pupil_radius * 2, pupil_radius * 2),
            (20, 20, 20, 255),
            (0, 0, 0, 255),
            radius_factor=1.0
        )
        image.paste(
            pupil_img,
            (center_x - pupil_radius, center_y - pupil_radius),
            pupil_img
        )

        # Subtle highlight on pupil
        highlight_radius = pupil_radius // 3
        highlight_offset_x = -pupil_radius // 3
        highlight_offset_y = -pupil_radius // 3
        highlight_bbox = [
            center_x + highlight_offset_x - highlight_radius // 2,
            center_y + highlight_offset_y - highlight_radius // 2,
            center_x + highlight_offset_x + highlight_radius // 2,
            center_y + highlight_offset_y + highlight_radius // 2
        ]
        draw.ellipse(highlight_bbox, fill=light + (100,))

    return image


def draw_well_icon(size, color_scheme=None, is_template=False):
    """
    Draw Well/Portal - concentric rings only (no M).

    Args:
        size: Icon size in pixels
        color_scheme: Dict with 'primary', 'dark', 'light' colors (or None for template)
        is_template: If True, draw in black for template mode
    """
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    center = size // 2

    if is_template:
        color = BLACK
        # Draw 4 concentric circles with alternating thickness
        ring_specs = [
            (0.42, 2),  # Outer ring - thinner
            (0.33, 3),  # Second ring - thicker
            (0.24, 2),  # Third ring - thinner
            (0.15, 3),  # Inner ring - thicker
        ]

        for radius_factor, thickness_mult in ring_specs:
            radius = int(size * radius_factor)
            bbox = [
                center - radius,
                center - radius,
                center + radius,
                center + radius
            ]
            width = max(1, size // (25 // thickness_mult))
            draw.ellipse(bbox, outline=color, width=width)
    else:
        # Full color with alternating colors and glows
        colors = color_scheme
        primary = colors['primary']
        dark = colors['dark']
        light = colors['light']

        # Ring specs: (radius_factor, color_key, stroke_multiplier)
        ring_specs = [
            (0.42, light, 1.5),
            (0.33, primary, 2.5),
            (0.24, light, 1.5),
            (0.15, dark, 2.5),
        ]

        # Draw from outside in for proper layering
        for radius_factor, ring_color, stroke_mult in ring_specs:
            radius = int(size * radius_factor)
            bbox = [
                center - radius,
                center - radius,
                center + radius,
                center + radius
            ]
            width = max(2, int(size * stroke_mult / 100))
            draw.ellipse(bbox, outline=ring_color, width=width)

        # Add central glow
        glow = create_radial_gradient(
            (size, size),
            light + (100,),
            primary + (0,),
            radius_factor=0.2
        )
        image = Image.alpha_composite(glow, image)

        # Add outer glow for depth
        outer_glow = image.copy()
        outer_glow = outer_glow.filter(ImageFilter.GaussianBlur(radius=size // 40))
        image = Image.alpha_composite(outer_glow, image)

    return image


def generate_icon_variations(concept_name, draw_func):
    """Generate all color variations for one icon concept."""
    print(f"Generating {concept_name} concept...")

    # Tray icons (template mode) - only need one set per concept
    tray_22 = draw_func(22, color_scheme=None, is_template=True)
    tray_22.save(f"assets/icons/concepts/{concept_name}_tray.png")

    tray_44 = draw_func(44, color_scheme=None, is_template=True)
    tray_44.save(f"assets/icons/concepts/{concept_name}_tray@2x.png")

    print(f"  ✓ {concept_name}_tray.png (22x22)")
    print(f"  ✓ {concept_name}_tray@2x.png (44x44)")

    # App icons in all colors
    for color_name, colors in COLOR_SCHEMES.items():
        app_icon = draw_func(512, color_scheme=colors, is_template=False)
        filename = f"{concept_name}_{color_name}_app.png"
        app_icon.save(f"assets/icons/concepts/{filename}")
        print(f"  ✓ {filename} (512x512, {color_name})")

    print()


def main():
    """Generate all icon concepts and variations."""
    print("Mimir Icon Generator (Revised)")
    print("=" * 60)
    print("Generating 2 concepts × 4 colors = 8 app icons + tray icons")
    print()

    concepts = [
        ("eye", draw_eye_icon),
        ("well", draw_well_icon)
    ]

    for name, draw_func in concepts:
        generate_icon_variations(name, draw_func)

    print("=" * 60)
    print("✓ All concepts generated!")
    print()
    print("Review the concepts in: assets/icons/concepts/")
    print("  - eye_[color]_app.png = Eye in each color scheme")
    print("  - well_[color]_app.png = Well in each color scheme")
    print("  - *_tray.png = Template mode (for system tray)")
    print()
    print("Color schemes: teal, orange, blue, purple")


if __name__ == "__main__":
    main()
