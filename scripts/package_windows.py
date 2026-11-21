"""Package only release files; never include test saves or machine logs."""
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
release = root / "build/v10/windows"
files = ["StartupPhase.exe", "开始前请读.txt", "GODOT-LICENSE.txt", "GODOT-THIRD-PARTY.txt", "FONT-LICENSES.txt"]

def digest(data):
    return hashlib.sha256(data).hexdigest()

manifest = {
    "name": "启动阶段 · 现场解谜版",
    "version": "0.10.0",
    "platform": "Windows x64",
    "engine": "Godot 4.5.1 stable",
    "files": [
        {"name": name, "bytes": (release / name).stat().st_size,
         "sha256": digest((release / name).read_bytes())} for name in files
    ],
}
(release / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
archive = root / "build/StartupPhase-0.10.0-Windows-x64.zip"
with ZipFile(archive, "w", ZIP_DEFLATED, compresslevel=6) as package:
    for name in files + ["manifest.json"]:
        package.write(release / name, "StartupPhase-0.10.0/" + name)
with ZipFile(archive) as package:
    assert package.testzip() is None, "ZIP CRC failure"
    assert len(package.namelist()) == len(files) + 1
    for item in manifest["files"]:
        assert digest(package.read("StartupPhase-0.10.0/" + item["name"])) == item["sha256"]
    assert "StartupPhase-0.10.0/开始前请读.txt" in package.namelist()
report = {"archive": archive.name, "bytes": archive.stat().st_size,
          "sha256": digest(archive.read_bytes()), "crc_verified": True,
          "all_embedded_hashes_verified": True, "utf8_filenames_verified": True}
(root / "build/v10/package-verification.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
