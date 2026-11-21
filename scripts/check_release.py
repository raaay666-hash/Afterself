"""Run isolated checks against the exact Windows game executable."""
import argparse, concurrent.futures, hashlib, json, shutil, subprocess, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--exe', type=Path, default=ROOT/'build/v10/windows/StartupPhase.exe')
p.add_argument('--out', type=Path, default=ROOT/'build/first-installer/qa')
p.add_argument('--window', action='store_true')
a = p.parse_args()
a.exe = a.exe.resolve()
a.out = a.out.resolve()
a.out.mkdir(parents=True, exist_ok=True)
tests = ['self-test','campaign-test','desk-test','collection-test','field-test']
if a.window:
    tests = ['field-window-test','collection-window-test','full-story-test','audio-smoke']

def run(name):
    folder = a.out/name
    folder.mkdir(parents=True, exist_ok=True)
    exe = folder/'StartupPhase.exe'
    shutil.copy2(a.exe, exe)
    log = folder/'godot.log'
    args = [str(exe)] + ([] if a.window else ['--headless']) + ['--log-file',str(log),'--','--'+name]
    start = time.monotonic()
    try:
        result = subprocess.run(args, cwd=folder, capture_output=True, timeout=420)
        output = log.read_text('utf-8', errors='replace') if log.exists() else ''
        warnings = [line for line in output.splitlines() if line == 'ERROR: Failed to read the root certificate store.']
        failures = [line for line in output.splitlines() if line not in warnings and any(v in line for v in ['SCRIPT ERROR','Parse Error','FAIL:','FAILURES:','TESTS FAILED','ERROR:'])]
        passed = result.returncode==0 and not failures and ('PASSED' in output or (name=='audio-smoke' and 'streams loaded=7' in output))
        report = dict(test=name, passed=passed, exit_code=result.returncode, seconds=round(time.monotonic()-start,2), failures=failures, environment_warnings=warnings, log=str(log))
    except subprocess.TimeoutExpired:
        report = dict(test=name, passed=False, error='timeout')
    exe.unlink(missing_ok=True)
    print(json.dumps(report,ensure_ascii=False),flush=True)
    return report

if a.window:
    results = [run(name) for name in tests]
else:
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(run,tests))
report = {'executable':str(a.exe),'sha256':hashlib.sha256(a.exe.read_bytes()).hexdigest(),'results':results,'passed':all(r['passed'] for r in results)}
(a.out/('window-results.json' if a.window else 'logic-results.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf-8')
raise SystemExit(0 if report['passed'] else 1)
