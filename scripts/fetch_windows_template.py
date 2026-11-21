"""Extract only the Windows release template from Godot's official ZIP using HTTP ranges.

Avoid downloading the multi-platform archive. Refuse servers that ignore Range.
Standard library only; verify ZIP CRC before writing the executable.
"""
import io
import struct
import sys
import urllib.request
import zipfile
import zlib
from pathlib import Path

URL = "https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_export_templates.tpz"

def fetch_range(url, start, end):
    req = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}", "User-Agent": "StartupPhaseBuild/0.1"})
    with urllib.request.urlopen(req, timeout=90) as response:
        if response.status != 206:
            raise RuntimeError("Server ignored HTTP Range; refused full archive download")
        expected = end-start+1
        raw = response.read(expected+1)
        if len(raw) != expected:
            raise RuntimeError(f"Unexpected range length {len(raw)} != {expected}")
        return raw

def main():
    with urllib.request.urlopen(urllib.request.Request(URL, method="HEAD"),timeout=90) as response:
        url = response.url
        total = int(response.headers["Content-Length"])
    tail_offset = max(0,total-131072)
    tail = fetch_range(url,tail_offset,total-1)
    pos = tail.rfind(b"PK\x05\x06")
    if pos < 0:
        raise RuntimeError("ZIP end record missing")
    _, disk, cd_disk, disk_count, count, cd_size, cd_offset, comment_size = struct.unpack_from("<4s4H2IH",tail,pos)
    if disk or cd_disk or cd_offset == 0xffffffff:
        raise RuntimeError("Unsupported multipart or ZIP64 archive")
    cd = fetch_range(url,cd_offset,cd_offset+cd_size-1)
    fake = io.BytesIO(cd+tail[pos:])
    with zipfile.ZipFile(fake) as archive:
        entries = archive.infolist()
        target = next(entry for entry in entries if entry.filename == "templates/windows_release_x86_64.exe")
        # zipfile compensates offsets for the synthetic central-directory-only ZIP.
        original_offset = target.header_offset + cd_offset
    local_header = fetch_range(url,original_offset,original_offset+29)
    if local_header[:4] != b"PK\x03\x04":
        raise RuntimeError("Invalid local header offset")
    name_size, extra_size = struct.unpack_from("<HH",local_header,26)
    data_offset = original_offset+30+name_size+extra_size
    compressed = fetch_range(url,data_offset,data_offset+target.compress_size-1)
    if target.compress_type == zipfile.ZIP_DEFLATED:
        raw = zlib.decompress(compressed,-15)
    elif target.compress_type == zipfile.ZIP_STORED:
        raw = compressed
    else:
        raise RuntimeError("Unsupported ZIP compression")
    if len(raw) != target.file_size or zlib.crc32(raw) & 0xffffffff != target.CRC:
        raise RuntimeError("Template ZIP CRC validation failed")
    output = Path(sys.argv[1])
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_bytes(raw)
    print(f"Extracted {target.filename}: {len(raw)} bytes, CRC32={target.CRC:08x}")
    print(f"Official archive: {URL}")

if __name__ == "__main__":
    main()
