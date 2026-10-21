#!/usr/bin/env python3
"""Install a development build with a stable Apple identity, never ad-hoc signing."""
import argparse
import datetime
from pathlib import Path
import re
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('app', type=Path)
parser.add_argument('--team', default='6S5C826R55')
args = parser.parse_args()
source = args.app.resolve()
if not (source / 'Contents/MacOS/SenseFlow').is_file():
    parser.error('Expected a built SenseFlow.app')
identities = subprocess.check_output(['security', 'find-identity', '-v', '-p', 'codesigning'], text=True)
matches = re.findall(r'([A-F0-9]{40}) "Apple Development: [^"\n]+ \(' + re.escape(args.team) + r'\)"', identities)
if len(matches) != 1:
    raise SystemExit('Expected exactly one valid Apple Development identity for the project team')
with tempfile.TemporaryDirectory(prefix='senseflow-install-') as scratch:
    candidate = Path(scratch) / 'SenseFlow.app'
    subprocess.run(['ditto', str(source), str(candidate)], check=True)
    binary = candidate / 'Contents/MacOS/SenseFlow'
    commands = subprocess.check_output(['otool', '-l', str(binary)], text=True).splitlines()
    for i, line in enumerate(commands):
        if 'cmd LC_RPATH' in line:
            path = commands[i + 2].strip().split('path ', 1)[-1].split(' (offset', 1)[0]
            if 'DerivedData' in path and 'PackageFrameworks' in path:
                subprocess.run(['install_name_tool', '-delete_rpath', path, str(binary)], check=True)
    # Sign nested code before the containing bundle.
    nested = list((candidate / 'Contents').rglob('*.framework')) + list((candidate / 'Contents').rglob('*.dylib'))
    for item in sorted(nested, key=lambda p: len(p.parts), reverse=True):
        subprocess.run(['codesign', '--force', '--sign', matches[0], str(item)], check=True)
    subprocess.run(['codesign', '--force', '--sign', matches[0], str(candidate)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(candidate)], check=True)
    signature = subprocess.run(['codesign', '-dv', str(candidate)], capture_output=True, text=True, check=True).stderr
    signed_team = re.search(r'^TeamIdentifier=(.+)$', signature, re.MULTILINE)
    if not signed_team or signed_team.group(1) == 'not set' or 'Signature=adhoc' in signature:
        raise SystemExit('Stable signature verification failed: ' + signature)
    subprocess.run(['swift', '-e', 'import AppKit; for app in NSRunningApplication.runningApplications(withBundleIdentifier: "com.senseflow.SenseFlow") { app.terminate() }'], check=True)
    for attempt in range(30):
        running = subprocess.run(['pgrep', '-f', '^/Applications/SenseFlow.app/Contents/MacOS/SenseFlow$'], capture_output=True)
        if running.returncode != 0:
            break
        time.sleep(0.1)
    if running.returncode == 0:
        raise SystemExit('Application still running; installation stopped')
    destination = Path('/Applications/SenseFlow.app')
    backup = Path.home() / '.Trash' / ('SenseFlow-before-stable-signing-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f') + '.app')
    if destination.exists():
        destination.rename(backup)
    try:
        subprocess.run(['ditto', str(candidate), str(destination)], check=True)
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(destination)], check=True)
    except Exception:
        if backup.exists() and not destination.exists():
            backup.rename(destination)
        raise
    subprocess.run(['open', str(destination)], check=True)
    print('Installed with stable Apple Development identity:', matches[0], 'Team:', signed_team.group(1))
