"""Precompute size-specific WoW TGA atlases with Lanczos resampling."""

from pathlib import Path
import sys

from PIL import Image


SIZES = {
    "XS": 128,
    "S": 128,
    "M": 256,
    "L": 256,
    "XL": 256,
}
SOURCE_FRAME = 512


def write_atlas(source: Image.Image, output: Path, frame_size: int) -> None:
    atlas = Image.new("RGBA", (frame_size * 4, frame_size))
    for index in range(3):
        crop = source.crop((index * SOURCE_FRAME, 0, (index + 1) * SOURCE_FRAME, SOURCE_FRAME))
        # Pre-scale once with a high-quality filter; the game only makes a small final adjustment.
        scaled = crop.resize((frame_size, frame_size), Image.Resampling.LANCZOS)
        atlas.alpha_composite(scaled, (index * frame_size, 0))
    atlas.save(output)


def main(art_directory: str) -> None:
    art = Path(art_directory)
    outline = Image.open(art / "BongoCatClassic.tga").convert("RGBA")
    fill = Image.open(art / "BongoCatClassicFill.tga").convert("RGBA")
    for label, frame_size in SIZES.items():
        write_atlas(outline, art / f"BongoCatClassic-{label}.tga", frame_size)
        write_atlas(fill, art / f"BongoCatClassicFill-{label}.tga", frame_size)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: make_size_atlases.py ART_DIRECTORY")
    main(sys.argv[1])
