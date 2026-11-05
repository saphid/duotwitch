#!/usr/bin/env python3
"""Render the app's simple two-panel mark without external dependencies."""
import json
import math
from pathlib import Path
import struct
import zlib

SIZE = 1024
BACKGROUND = (14, 14, 19)
CORAL = (255, 102, 82)
CREAM = (249, 241, 233)
pixels = bytearray(BACKGROUND * (SIZE * SIZE))


def span(y, start, end, color):
    start, end = max(0, int(start)), min(SIZE, int(end))
    if end > start:
        offset = (y * SIZE + start) * 3
        pixels[offset:offset + (end - start) * 3] = bytes(color) * (end - start)


def rounded_rectangle(x, y, width, height, radius, color):
    for row in range(y, y + height):
        distance = max(y + radius - row - 0.5, row + 0.5 - (y + height - radius), 0)
        inset = radius - math.sqrt(max(0, radius * radius - distance * distance))
        span(row, x + inset, x + width - inset, color)


rounded_rectangle(144, 230, 470, 564, 56, CORAL)
rounded_rectangle(650, 230, 230, 564, 56, CREAM)
for row in range(400, 625):
    half = 112.5 - abs(row - 512.5)
    span(row, 310, 310 + half * 1.62, BACKGROUND)
for row in (426, 496, 566):
    rounded_rectangle(694, row, 142 if row != 566 else 96, 24, 12, BACKGROUND)


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


rows = b"".join(b"\x00" + pixels[y * SIZE * 3:(y + 1) * SIZE * 3] for y in range(SIZE))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b"")
target = Path(__file__).resolve().parents[1] / "App/Assets.xcassets/AppIcon.appiconset"
target.mkdir(parents=True, exist_ok=True)
(target / "AppIcon.png").write_bytes(png)
(target / "Contents.json").write_text(json.dumps({"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
