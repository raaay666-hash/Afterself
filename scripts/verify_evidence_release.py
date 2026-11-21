"""Inspect embedded Godot 4.5 PCK v3 and verify each packaged file hash."""
from pathlib import Path
import argparse
import hashlib
import json
import struct

root = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--exe', type=Path, default=root/'build/first-installer/stage/StartupPhase.exe')
p.add_argument('--report', type=Path, default=root/'build/first-installer/resource-verification.json')
a = p.parse_args()
exe = a.exe.resolve()
data = exe.read_bytes()
length, magic = struct.unpack_from('<QI', data, len(data)-12)
assert magic == 0x43504447
start = len(data)-12-length
assert struct.unpack_from('<II', data, start) == (magic, 3)
base, directory = struct.unpack_from('<QQ', data, start+24)
pos = start + directory
count = struct.unpack_from('<I', data, pos)[0]
pos += 4
paths = []
for _ in range(count):
    size = struct.unpack_from('<I', data, pos)[0]
    pos += 4
    name = data[pos:pos+size].rstrip(b'\0').decode('utf-8')
    pos += size
    offset, file_size = struct.unpack_from('<QQ', data, pos)
    expected = data[pos+16:pos+32]
    flags = struct.unpack_from('<I', data, pos+32)[0]
    pos += 36
    assert flags == 0, name
    payload = data[start+base+offset:start+base+offset+file_size]
    assert len(payload) == file_size and hashlib.md5(payload).digest() == expected, name
    paths.append(name)

runtime = json.loads((root/'assets/evidence-runtime-v9.json').read_text('utf-8'))
expected_images = {
    'assets/evidence-models-v2/'+entry['assets'][view]+'.import'
    for entry in runtime['entries'] for view in ('icon','front','secondary')
}
evidence_paths = {p for p in paths if p.startswith('assets/evidence-models-v2/')}
assert evidence_paths == expected_images, (sorted(evidence_paths-expected_images), sorted(expected_images-evidence_paths))
assert not any('evidence-models-v1' in p for p in paths)
assert 'assets/evidence-runtime-v9.json' in paths
assert not any(p.startswith(('build/','docs/','.tools/','installer/','installer-prototype/')) or p.endswith('.py') for p in paths)
assert 'assets/campaign-v5.json' in paths
assert 'assets/investigation-v6.json' in paths
assert 'assets/fieldwork-v10.json' in paths
assert all('assets/scenes/'+scene in paths or 'assets/scenes/'+scene+'.import' in paths for scene in ['apartment.png','corridor.png','archive.png','street.png','oldquarter-v5.png','clinic-v5.png','waterworks-v5.png','server-v5.png','boardroom-v5.png'])
report = {
    'executable': str(exe), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
    'pck_files': count, 'all_packaged_md5_verified': True,
    'evidence_entries': len(runtime['entries']), 'evidence_images': len(expected_images),
    'hotspots': sum(len(e['hotspots']) for e in runtime['entries']),
    'only_final_v2_images': True, 'v1_and_preview_assets_excluded': True,
}
a.report.parent.mkdir(parents=True,exist_ok=True)
a.report.write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
