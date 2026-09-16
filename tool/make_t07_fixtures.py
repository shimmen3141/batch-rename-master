"""008:T07 の manual 確認用 fixture を作る(標準ライブラリだけ)。

格子と正円の PNG 24枚(縦横比8種 x 3)、中身が画像でない broken-fixture.jpg、
notes.txt、report.pdf の計27件。
"""
import math
import pathlib
import struct
import sys
import zlib

out = pathlib.Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)

RATIOS = [(1, 1), (4, 3), (3, 4), (16, 9), (9, 16), (3, 2), (2, 3), (21, 9)]
PALETTE = [(34, 211, 238), (248, 113, 113), (74, 222, 128)]


def png(path, w, h, fg):
    cell = max(8, min(w, h) // 8)
    cx, cy, r = w / 2, h / 2, min(w, h) * 0.4
    rows = bytearray()
    for y in range(h):
        rows.append(0)
        for x in range(w):
            on_grid = x % cell < 2 or y % cell < 2
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            on_circle = abs(d - r) < 2.5
            if on_circle:
                px = (255, 255, 255)
            elif on_grid:
                px = fg
            else:
                px = (18, 21, 26)
            rows += bytes(px)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
        + chunk(b"IEND", b"")
    )


n = 0
for i, (a, b) in enumerate(RATIOS):
    for j, fg in enumerate(PALETTE):
        base = 480
        w, h = (base, base * b // a) if a >= b else (base * a // b, base)
        n += 1
        png(out / f"grid-{n:02d}-{a}x{b}.png", w, h, fg)

(out / "broken-fixture.jpg").write_bytes(b"not-an-image\n")
(out / "notes.txt").write_text("t07 fixture\n", encoding="utf-8")

objs = [
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>",
]
pdf = bytearray(b"%PDF-1.4\n")
offsets = []
for k, body in enumerate(objs, 1):
    offsets.append(len(pdf))
    pdf += b"%d 0 obj\n" % k + body + b"\nendobj\n"
xref = len(pdf)
pdf += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
for o in offsets:
    pdf += b"%010d 00000 n \n" % o
pdf += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)
(out / "report.pdf").write_bytes(bytes(pdf))

print(len(list(out.iterdir())), "files in", out)
