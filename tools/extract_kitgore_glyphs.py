"""Extract the Bongo Cat icon-font glyphs as standalone SVG files.

Run with FontTools available, for example:
  python tools/extract_kitgore_glyphs.py path/to/bongocat.woff output-directory
"""

from pathlib import Path
import sys

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont


POSES = {
    "left-up": "b",
    "left-down": "d",
    "right-up": "c",
    "right-down": "a",
}


def main(font_path: str, output_directory: str) -> None:
    font = TTFont(font_path)
    glyph_set = font.getGlyphSet()
    cmap = font.getBestCmap()
    ascent = font["hhea"].ascent
    descent = font["hhea"].descent
    height = ascent - descent
    output = Path(output_directory)
    output.mkdir(parents=True, exist_ok=True)

    for pose, character in POSES.items():
        glyph_name = cmap[ord(character)]
        advance_width = font["hmtx"].metrics[glyph_name][0]
        pen = SVGPathPen(glyph_set)
        glyph_set[glyph_name].draw(pen)
        svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {advance_width} {height}" width="{advance_width}" height="{height}">
  <path fill="currentColor" d="{pen.getCommands()}" transform="translate(0 {ascent}) scale(1 -1)"/>
</svg>
'''
        (output / f"{pose}.svg").write_text(svg, encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: extract_kitgore_glyphs.py FONT.woff OUTPUT_DIRECTORY")
    main(sys.argv[1], sys.argv[2])
