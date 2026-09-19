#!/usr/bin/env python3
"""Render a TrueType font to a BMFont text descriptor (.fnt) and an 8-bit
PNG atlas, the format Connect IQ's resource compiler reads.

Usage:
    make_bitmap_font.py FONT.ttf OUT_PREFIX --size 48 --weight 500 --chars 0123456789

Writes OUT_PREFIX.fnt and OUT_PREFIX_0.png. --size is the em size in pixels
and --weight sets the wght axis of a variable font (ignored for static fonts).
Requires Pillow.
"""
import argparse
import math
import os

from PIL import Image, ImageDraw, ImageFont


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("font")
    parser.add_argument("out_prefix")
    parser.add_argument("--size", type=int, required=True)
    parser.add_argument("--weight", type=int)
    parser.add_argument("--chars", default="0123456789")
    args = parser.parse_args()

    font = ImageFont.truetype(args.font, args.size)
    if args.weight is not None:
        font.set_variation_by_axes([args.weight])

    # The line box is fitted tightly around the glyphs (top of the tallest to
    # bottom of the lowest) rather than using the font's ascent/descent, so
    # drawing with TEXT_JUSTIFY_VCENTER centers the digits themselves.
    raw = []
    for ch in args.chars:
        left, top, right, bottom = font.getbbox(ch, anchor="ls")
        raw.append((ch, math.floor(left), math.floor(top), math.ceil(right), math.ceil(bottom)))
    box_top = min(r[2] for r in raw)
    box_bottom = max(r[4] for r in raw)

    glyphs = []
    for ch, x0, y0, x1, y1 in raw:
        image = Image.new("L", (max(x1 - x0, 1), max(y1 - y0, 1)), 0)
        ImageDraw.Draw(image).text((-x0, -y0), ch, font=font, fill=255, anchor="ls")
        glyphs.append((ch, image, x0, y0 - box_top, round(font.getlength(ch))))

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
