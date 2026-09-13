"""Build a tintable interior-fill atlas from the opaque outline atlas."""

from collections import deque
from pathlib import Path
import sys

from PIL import Image


FRAME_SIZE = 512


def enclosed_transparency(frame: Image.Image) -> Image.Image:
    alpha = frame.getchannel("A")
    pixels = alpha.load()
    outside = set()
    pending = deque()

    def add(x, y):
        if (x, y) not in outside and pixels[x, y] == 0:
            outside.add((x, y))
            pending.append((x, y))

    for x in range(FRAME_SIZE):
        add(x, 0)
        add(x, FRAME_SIZE - 1)
    for y in range(FRAME_SIZE):
        add(0, y)
        add(FRAME_SIZE - 1, y)

    while pending:
        x, y = pending.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < FRAME_SIZE and 0 <= ny < FRAME_SIZE:
                add(nx, ny)

    fill = Image.new("RGBA", frame.size)
    out = fill.load()
    for y in range(FRAME_SIZE):
        for x in range(FRAME_SIZE):
            if pixels[x, y] == 0 and (x, y) not in outside:
                out[x, y] = (255, 255, 255, 255)
    return fill


def main(source_path: str, output_path: str) -> None:
    source = Image.open(source_path).convert("RGBA")
    if source.size != (2048, 512):
        raise ValueError(f"Expected 2048x512 atlas, got {source.size}")
    result = Image.new("RGBA", source.size)
    for index in range(3):
        box = (index * FRAME_SIZE, 0, (index + 1) * FRAME_SIZE, FRAME_SIZE)
        result.paste(enclosed_transparency(source.crop(box)), box)
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    result.save(output_path)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: make_kitgore_fill.py OUTLINE.tga FILL.tga")
    main(sys.argv[1], sys.argv[2])
