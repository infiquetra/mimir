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

    # Elliptical eye outline (almond shape) - sized for visibility at small sizes
    eye_width = int(size * 0.85)
    eye_height = int(size * 0.45)
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
    iris_radius = int(size * 0.22)
    iris_stroke = max(2, size // 25)
    iris_bbox = [
        center_x - iris_radius,
        center_y - iris_radius,
        center_x + iris_radius,
        center_y + iris_radius
    ]
    draw.ellipse(iris_bbox, outline=stroke_color, width=iris_stroke)

    # Pupil (filled)
    pupil_radius = int(size * 0.10)
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


def draw_eye_menu_icon(size):
    """Draw eye icon for Dashboard menu item (template mode)."""
    return draw_eye_tray_style(size, is_template=True)


def draw_skillbook_menu_icon(size):
    """Draw skill book icon for Skills menu item (template mode)."""
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Book dimensions
    book_width = int(size * 0.60)
    book_height = int(size * 0.70)
    center_x = size // 2
    center_y = size // 2

    stroke = max(1, size // 16)

    # Book rectangle
    book_left = center_x - book_width // 2
    book_top = center_y - book_height // 2
    book_right = center_x + book_width // 2
    book_bottom = center_y + book_height // 2

    # Draw book outline
    draw.rectangle(
        [book_left, book_top, book_right, book_bottom],
        outline=BLACK,
        width=stroke
    )

    # Draw spine (vertical line in middle)
    draw.line(
        [(center_x, book_top), (center_x, book_bottom)],
        fill=BLACK,
        width=stroke
    )

    # Draw bookmark (small triangle at top)
    bookmark_width = int(book_width * 0.25)
    bookmark_height = int(book_height * 0.30)
    draw.polygon([
        (center_x + book_width // 4, book_top),
        (center_x + book_width // 4 - bookmark_width // 2, book_top + bookmark_height),
        (center_x + book_width // 4 + bookmark_width // 2, book_top + bookmark_height),
    ], fill=BLACK)

    return image


def draw_isk_menu_icon(size):
    """Draw ISK symbol (Z with strokes) for Wallet menu item (template mode)."""
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Z dimensions
    z_width = int(size * 0.50)
    z_height = int(size * 0.65)
    center_x = size // 2
    center_y = size // 2

    stroke = max(2, size // 12)

    # Z bounds
    left = center_x - z_width // 2
    right = center_x + z_width // 2
    top = center_y - z_height // 2
    bottom = center_y + z_height // 2

    # Draw Z shape (top horizontal, diagonal, bottom horizontal)
    # Top line
    draw.line([(left, top), (right, top)], fill=BLACK, width=stroke)
    # Diagonal
    draw.line([(right, top), (left, bottom)], fill=BLACK, width=stroke)
    # Bottom line
    draw.line([(left, bottom), (right, bottom)], fill=BLACK, width=stroke)

    # Add horizontal strokes through middle (ISK currency symbol)
    middle_y = center_y
    stroke_offset = int(size * 0.08)

    # Upper stroke
    draw.line(
        [(left - stroke, middle_y - stroke_offset), (right + stroke, middle_y - stroke_offset)],
        fill=BLACK,
        width=max(1, stroke // 2)
    )
    # Lower stroke
    draw.line(
        [(left - stroke, middle_y + stroke_offset), (right + stroke, middle_y + stroke_offset)],
        fill=BLACK,
        width=max(1, stroke // 2)
    )

    return image


def draw_character_menu_icon(size):
    """Draw human in octagon for Characters menu item (template mode)."""
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    center_x = size // 2
    center_y = size // 2
    radius = int(size * 0.42)
    stroke = max(1, size // 16)

    # Draw octagon
    import math
    points = []
    for i in range(8):
        angle = i * (2 * math.pi / 8) - math.pi / 8  # Start from top-right
        x = center_x + radius * math.cos(angle)
        y = center_y + radius * math.sin(angle)
        points.append((x, y))

    draw.polygon(points, outline=BLACK, width=stroke)

    # Draw human silhouette (head and shoulders)
    # Head (circle)
    head_radius = int(size * 0.12)
    head_y = center_y - int(size * 0.10)
    head_bbox = [
        center_x - head_radius,
        head_y - head_radius,
        center_x + head_radius,
        head_y + head_radius
    ]
    draw.ellipse(head_bbox, fill=BLACK)

    # Shoulders (trapezoid/arc)
    shoulder_width = int(size * 0.35)
    shoulder_top_y = head_y + head_radius + max(1, size // 32)
    shoulder_bottom_y = center_y + int(size * 0.20)

    # Simple shoulders as filled polygon
    shoulder_points = [
        (center_x - shoulder_width // 3, shoulder_top_y),
        (center_x + shoulder_width // 3, shoulder_top_y),
        (center_x + shoulder_width // 2, shoulder_bottom_y),
        (center_x - shoulder_width // 2, shoulder_bottom_y),
    ]
    draw.polygon(shoulder_points, fill=BLACK)

    return image


def draw_question_menu_icon(size):
    """Draw question mark for Tutorial menu item (template mode)."""
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    center_x = size // 2
    center_y = size // 2
    stroke = max(2, size // 10)

    # Question mark dimensions
    arc_radius = int(size * 0.20)
    arc_top_y = center_y - int(size * 0.25)

    # Top arc of question mark (draw as thick arc)
    arc_bbox = [
        center_x - arc_radius,
        arc_top_y - arc_radius // 2,
        center_x + arc_radius,
        arc_top_y + arc_radius + arc_radius // 2
    ]
    draw.arc(arc_bbox, start=180, end=0, fill=BLACK, width=stroke)

    # Vertical stem
    stem_top_y = arc_top_y + arc_radius // 2
    stem_bottom_y = center_y + int(size * 0.05)
    draw.line(
        [(center_x, stem_top_y), (center_x, stem_bottom_y)],
        fill=BLACK,
        width=stroke
    )

    # Dot at bottom
    dot_radius = max(1, size // 16)
    dot_y = center_y + int(size * 0.20)
    dot_bbox = [
        center_x - dot_radius,
        dot_y - dot_radius,
        center_x + dot_radius,
        dot_y + dot_radius
    ]
    draw.ellipse(dot_bbox, fill=BLACK)

    return image


def draw_gear_menu_icon(size):
    """Draw gear/cog for Settings menu item (template mode)."""
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    import math
    center_x = size // 2
    center_y = size // 2

    # Gear parameters
    outer_radius = int(size * 0.42)
    inner_radius = int(size * 0.28)
    center_hole_radius = int(size * 0.12)
    num_teeth = 6
    tooth_width = math.pi / (num_teeth * 1.5)

    # Draw gear teeth as polygon
    points = []
    for i in range(num_teeth * 2):
        angle = i * math.pi / num_teeth
        if i % 2 == 0:
            # Tooth tip
            radius = outer_radius
        else:
            # Tooth valley
            radius = inner_radius

        x = center_x + radius * math.cos(angle)
        y = center_y + radius * math.sin(angle)
        points.append((x, y))

    # Draw filled gear
    draw.polygon(points, fill=BLACK)

    # Cut out center hole
    hole_bbox = [
        center_x - center_hole_radius,
        center_y - center_hole_radius,
        center_x + center_hole_radius,
        center_y + center_hole_radius
    ]
    # Draw hole as transparent circle (draw white then composite)
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.polygon(points, fill=255)
    mask_draw.ellipse(hole_bbox, fill=0)

    # Apply mask
    final_image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    final_image.paste(BLACK, (0, 0), mask)

    return final_image


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

    # Generate menu icons (template mode)
    print("Generating tray menu icons...")

    menu_icons = {
        'dashboard': draw_eye_menu_icon,
        'skills': draw_skillbook_menu_icon,
        'wallet': draw_isk_menu_icon,
        'characters': draw_character_menu_icon,
        'tutorial': draw_question_menu_icon,
        'settings': draw_gear_menu_icon,
    }

    for name, draw_func in menu_icons.items():
        # 1x size (16x16)
        icon_16 = draw_func(16)
        icon_16.save(f"assets/icons/tray/{name}.png")
        print(f"  ✓ {name}.png (16x16)")

        # 2x size (32x32)
        icon_32 = draw_func(32)
        icon_32.save(f"assets/icons/tray/{name}@2x.png")
        print(f"  ✓ {name}@2x.png (32x32)")

    print()
    print("=" * 60)
    print("✓ Final icon set generated!")
    print()
    print("Files created:")
    print("  - macOS app icons: macos/.../AppIcon.appiconset/app_icon_*.png")
    print("  - System tray: assets/icons/eve/app_icon.png + @2x")
    print("  - Menu icons: assets/icons/tray/*.png + @2x")


if __name__ == "__main__":
    generate_icon_set()
