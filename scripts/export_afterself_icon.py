"""Convert the generated AFTERSELF artwork to Windows ICO; no repainting."""
from io import BytesIO
from pathlib import Path
import struct
import sys
from PIL import Image

root = Path(__file__).resolve().parents[1]
branding = root / 'assets' / 'branding'
stem = sys.argv[1] if len(sys.argv) > 1 else 'afterself-icon'
art = Image.open(branding / (stem + '.png')).convert('RGBA')
assert art.width == art.height, 'Icon artwork must be square'
sizes = (16, 24, 32, 48, 64, 128, 256)
frames = []
for size in sizes:
    frame = BytesIO()
    art.resize((size, size), Image.Resampling.NEAREST).save(frame, format='PNG')
    frames.append(frame.getvalue())
offset = 6 + 16 * len(frames)
ico = bytearray(struct.pack('<HHH', 0, 1, len(frames)))
for size, frame in zip(sizes, frames):
    ico.extend(struct.pack('<BBBBHHII', size % 256, size % 256, 0, 0, 1, 32, len(frame), offset))
    offset += len(frame)
for frame in frames:
    ico.extend(frame)
(branding / (stem + '.ico')).write_bytes(ico)

# Format proof only; the generated composition and lettering are unchanged.
proof = Image.new('RGB', (720, 280), '#28262a')
x = 18
for size in sizes:
    frame = art.resize((size, size), Image.Resampling.NEAREST)
    proof.paste(frame, (x, 12))
    x += size + 18
proof.save(branding / (stem + '-size-proof.png'))
print('Exported AFTERSELF ICO sizes:', sizes)
