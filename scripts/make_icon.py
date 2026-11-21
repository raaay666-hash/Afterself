"""Render the proposed 《第二原件》 character-led pixel icon."""

from io import BytesIO
from pathlib import Path
import struct

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "branding"
OUT.mkdir(parents=True, exist_ok=True)
FONT = ROOT / "assets" / "fonts" / "pixel-small.otf"

NAVY = "#11161d"
NIGHT = "#202b35"
INK = "#171b20"
COAT = "#404e56"
COAT_LIGHT = "#627076"
SKIN = "#b29a83"
SKIN_LIGHT = "#d0baa2"
PAPER = "#d9ceba"
AMBER = "#ab8d65"
GHOST = "#374955"

art = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
d = ImageDraw.Draw(art)

# A clipped night-window silhouette, with quiet city lights behind the figure.
d.polygon([(6, 0), (90, 0), (96, 6), (96, 90), (90, 96), (6, 96), (0, 90), (0, 6)], fill=NAVY)
d.rectangle((4, 4, 91, 77), fill=NIGHT)
for x, y, h in ((8, 21, 29), (17, 13, 32), (74, 10, 43), (84, 25, 28)):
    d.rectangle((x, y, x + 2, y + h), fill="#2a3944")
for x, y in ((12, 31), (19, 20), (79, 28), (86, 39), (72, 48)):
    d.rectangle((x, y, x + 1, y + 3), fill="#80705e")
d.rectangle((4, 75, 91, 77), fill="#313d47")

# Faint second presence: an offset version of Lin Yan, separated by the dark
# strip. It does not merge into the foreground person's outline.
d.polygon([(58, 23), (64, 16), (75, 17), (80, 25), (79, 37), (74, 44),
           (82, 52), (88, 66), (87, 76), (61, 76), (60, 47)], fill=GHOST)
d.polygon([(66, 27), (75, 27), (77, 34), (74, 41), (67, 40)], fill="#5d6f76")
d.rectangle((63, 23, 76, 27), fill="#2c3c48")
d.rectangle((63, 40, 80, 45), fill=NIGHT)

# Foreground: the game's digital investigator, Lin Yan. One gray hair notch,
# a short asymmetrical dark-teal coat, cream cuff, and ochre notebook are his
# existing character cues. Forms stay coarse enough for icon-size reduction.
d.polygon([(22, 65), (27, 54), (39, 49), (54, 49), (66, 54), (74, 66),
           (72, 78), (18, 78)], fill=COAT)
d.polygon([(39, 47), (52, 46), (56, 56), (45, 64), (36, 55)], fill=SKIN)
d.polygon([(42, 52), (50, 53), (52, 69), (44, 76), (36, 69)], fill=PAPER)
d.polygon([(33, 52), (43, 61), (39, 78), (27, 78), (24, 64)], fill="#34414a")
d.polygon([(55, 52), (63, 55), (70, 70), (66, 78), (48, 78), (47, 63)], fill=COAT)
d.polygon([(52, 56), (59, 53), (64, 58), (56, 69), (49, 63)], fill=COAT_LIGHT)

# Face is three-quarter view, looking into the illuminated side of the frame.
d.polygon([(34, 21), (52, 17), (62, 24), (63, 36), (58, 44), (49, 49),
           (37, 45), (31, 35)], fill=SKIN)
d.polygon([(45, 23), (57, 24), (60, 31), (59, 39), (52, 44), (43, 42)], fill=SKIN_LIGHT)
d.rectangle((58, 31, 64, 36), fill=SKIN_LIGHT)
d.rectangle((55, 30, 57, 32), fill=INK)
d.rectangle((60, 37, 63, 38), fill="#866d61")
d.rectangle((32, 32, 35, 37), fill=SKIN)

# A deliberately uneven hairline, not a generic circular avatar.
d.polygon([(30, 19), (36, 12), (49, 10), (58, 14), (64, 21), (62, 28),
           (54, 24), (47, 24), (43, 31), (38, 28), (36, 39), (31, 34)], fill=INK)
d.rectangle((43, 13, 49, 16), fill="#717779")
d.rectangle((48, 16, 52, 19), fill="#717779")
d.rectangle((38, 28, 42, 34), fill="#2b2e32")

# Notebook and exposed cuff are plot-specific recognition details.
d.polygon([(19, 55), (32, 57), (31, 73), (17, 71)], fill=AMBER)
d.rectangle((20, 58, 30, 60), fill="#c6ab83")
d.rectangle((20, 62, 22, 67), fill="#75634c")
d.polygon([(28, 65), (35, 63), (41, 69), (35, 73), (28, 71)], fill=PAPER)
d.rectangle((34, 70, 41, 73), fill=SKIN)

# The title is part of the icon, rendered from the same licensed pixel font
# already shipped with the game. Hard thresholding removes font smoothing.
d.rectangle((4, 78, 91, 93), fill=NAVY)
d.rectangle((7, 78, 88, 79), fill=AMBER)
font = ImageFont.truetype(str(FONT), 16)
word = Image.new("L", (96, 19), 0)
wd = ImageDraw.Draw(word)
box = wd.textbbox((0, 0), "第二原件", font=font, stroke_width=0)
wd.text(((96 - (box[2] - box[0])) // 2 - box[0], -box[1]), "第二原件", fill=255, font=font)
word = word.point(lambda value: 255 if value >= 100 else 0)
art.paste(PAPER, (0, 80, 96, 99), word)

art.resize((768, 768), Image.Resampling.NEAREST).save(OUT / "second-original-icon.png")

sizes = (16, 24, 32, 48, 64, 128, 256)
frames = []
for size in sizes:
    frame = BytesIO()
    art.resize((size, size), Image.Resampling.NEAREST).save(frame, format="PNG")
    frames.append(frame.getvalue())
offset = 6 + len(frames) * 16
ico = bytearray(struct.pack("<HHH", 0, 1, len(frames)))
for size, frame in zip(sizes, frames):
    ico.extend(struct.pack("<BBBBHHII", size % 256, size % 256, 0, 0, 1, 32, len(frame), offset))
    offset += len(frame)
for frame in frames:
    ico.extend(frame)
(OUT / "second-original-icon.ico").write_bytes(ico)

proof = Image.new("RGB", (640, 340), "#dfe4df")
x = 20
for size in (16, 24, 32, 48, 64, 128, 256):
    small = art.resize((size, size), Image.Resampling.NEAREST)
    proof.paste(small, (x, 20), mask=small.getchannel("A"))
    x += size + 12
proof.save(OUT / "second-original-size-proof.png")
print(OUT)
