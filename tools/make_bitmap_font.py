#!/usr/bin/env python3
"""Render a TrueType font to a BMFont text descriptor (.fnt) and an 8-bit
PNG atlas, the format Connect IQ's resource compiler reads.

Usage:
    make_bitmap_font.py FONT.ttf OUT_PREFIX --size 48 --weight 500 --chars 0123456789

Writes OUT_PREFIX.fnt and OUT_PREFIX_0.png. --size is the em size in pixels
and --weight sets the wght axis of a variable font (ignored for static fonts).
Glyphs are rendered --supersample times larger and averaged down, which
gives smooth anti-aliased edges without the font's hinting snapping strokes
to the pixel grid (small hinted text looks jagged). --invert is for
"highlight" fonts whose glyphs are a solid block with the character cut out:
it flips each glyph so only the character remains, and trims the glyph and
the line box to it. Requires Pillow.
"""
import argparse
import math
import os

from PIL import Image, ImageDraw, ImageFont, ImageOps


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("font")
    parser.add_argument("out_prefix")
    parser.add_argument("--size", type=int, required=True)
    parser.add_argument("--weight", type=int)
    parser.add_argument("--chars", default="0123456789")
    parser.add_argument("--supersample", type=int, default=4)
    parser.add_argument("--invert", action="store_true")
    args = parser.parse_args()

    ss = args.supersample
    font = ImageFont.truetype(args.font, args.size * ss)
    if args.weight is not None:
        font.set_variation_by_axes([args.weight])

    # The line box is fitted tightly around the glyphs (top of the tallest to
    # bottom of the lowest) rather than using the font's ascent/descent, so
    # drawing with TEXT_JUSTIFY_VCENTER centers the digits themselves.
    # Glyph boxes are measured in supersampled pixels and snapped to
    # multiples of ss so the baseline stays on the real pixel grid.
    glyphs = []  # (char, image, x offset, top relative to baseline, advance)
    for ch in args.chars:
        left, top, right, bottom = font.getbbox(ch, anchor="ls")
        x0, y0 = math.floor(left / ss) * ss, math.floor(top / ss) * ss
        x1, y1 = math.ceil(right / ss) * ss, math.ceil(bottom / ss) * ss
        big = Image.new("L", (max(x1 - x0, ss), max(y1 - y0, ss)), 0)
        ImageDraw.Draw(big).text((-x0, -y0), ch, font=font, fill=255, anchor="ls")
        image = big.resize((big.width // ss, big.height // ss), Image.BOX)
        xoffset, ytop = x0 // ss, y0 // ss
        if args.invert:
            # Shrink the block by a pixel so its partly covered outer edge
            # pixels don't turn into bright ink when inverted.
            left, top, right, bottom = image.getbbox()
            block = (left + 1, top + 1, right - 1, bottom - 1)
            image = image.crop(block)
            xoffset += block[0]
            ytop += block[1]
            image = ImageOps.invert(image)
            # Faint edge pixels along the old block's border must not count as
            # ink, so measure with a threshold and keep one pixel of margin.
            left, top, right, bottom = image.point(lambda v: 255 if v > 100 else 0).getbbox()
            ink = (max(left - 1, 0), max(top - 1, 0), min(right + 1, image.width), min(bottom + 1, image.height))
            image = image.crop(ink)
            xoffset += ink[0]
            ytop += ink[1]
        glyphs.append((ch, image, xoffset, ytop, round(font.getlength(ch) / ss)))

    # The line box is fitted tightly around the glyphs (top of the tallest to
    # bottom of the lowest) rather than using the font's ascent/descent, so
    # drawing with TEXT_JUSTIFY_VCENTER centers the glyphs themselves.
    box_top = min(g[3] for g in glyphs)
    box_bottom = max(g[3] + g[1].height for g in glyphs)
    glyphs = [(ch, image, xoffset, ytop - box_top, advance) for ch, image, xoffset, ytop, advance in glyphs]

    spacing = 1
    atlas_w = sum(g[1].width + spacing for g in glyphs) + spacing
    atlas_h = max(g[1].height for g in glyphs) + 2 * spacing
    atlas = Image.new("L", (atlas_w, atlas_h), 0)

    png_name = os.path.basename(args.out_prefix) + "_0.png"
    lines = [
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=%d,%d outline=0'
        % (os.path.basename(args.font), args.size, spacing, spacing),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0"
        % (box_bottom - box_top, -box_top, atlas_w, atlas_h),
        'page id=0 file="%s"' % png_name,
        "chars count=%d" % len(glyphs),
    ]
    x = spacing
    for ch, image, xoffset, yoffset, xadvance in glyphs:
        atlas.paste(image, (x, spacing))
        lines.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15"
            % (ord(ch), x, spacing, image.width, image.height, xoffset, yoffset, xadvance)
        )
        x += image.width + spacing

    atlas.save(args.out_prefix + "_0.png")
    with open(args.out_prefix + ".fnt", "w") as f:
        f.write("\n".join(lines) + "\n")

    for ch, image, _, _, _ in glyphs:
        print("%s: %dx%d px" % (ch, image.width, image.height))


if __name__ == "__main__":
    main()
