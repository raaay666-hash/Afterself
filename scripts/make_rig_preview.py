"""QA only: assemble Godot-rendered frames and check opaque connectivity.

This does not edit any production art assets.
"""
import json
import sys
from collections import deque
from pathlib import Path
from PIL import Image

base = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / "build/v3"
for directory, duration in [("motion", 36), ("locomotion", 42)]:
    paths = sorted((base / directory).glob("frame-*.png"))
    if not paths:
        continue
    with Image.open(paths[0]) as first:
        palette = first.convert("RGB").quantize(colors=128)
    frames = []
    for path in paths:
        with Image.open(path) as frame:
            frames.append(frame.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE))
    frames[0].save(base / (directory + ".gif"), save_all=True, append_images=frames[1:],
                   duration=duration, loop=0, optimize=True, disposal=1)

report = []
for path in sorted((base / "isolated").glob("*.png")):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    mask = bytearray(1 if a > 230 else 0 for a in im.getchannel("A").get_flattened_data())
    components = []
    for start in range(len(mask)):
        if not mask[start]:
            continue
        mask[start] = 0
        queue = deque([start])
        area = 0
        while queue:
            p = queue.popleft()
            x, y = p % w, p // w
            area += 1
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        n = ny * w + nx
                        if mask[n]:
                            mask[n] = 0
                            queue.append(n)
        if area > 16:
            components.append(area)
    report.append({"frame": path.name, "opaque_components": sorted(components, reverse=True)})
failures = [entry for entry in report if len(entry["opaque_components"]) != 1]
result = {"frames_checked": len(report), "disconnected_frames": failures,
          "threshold": "8-connected alpha > 230; components > 16 rendered pixels"}
(base / "connectivity-check.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result, indent=2))
assert len(report) == 40 and not failures, "Rendered character connectivity check failed"
