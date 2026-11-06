#!/usr/bin/env python3
"""Opt-in local regression for macOS 27 menu-bar geometry.
--run changes 0/8/24 temporarily and refreshes known system items, including
Weather only when already running. User applications are not relaunched.
"""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

KEYS = ('NSStatusItemSpacing', 'NSStatusItemSelectionPadding')

def read():
    values = []
    for key in KEYS:
        p = subprocess.run(['defaults', '-currentHost', 'read', '-g', key], capture_output=True, text=True, timeout=10)
        if p.returncode == 0:
            values.append(int(p.stdout.strip()))
        elif 'Could not find key' in p.stderr or 'does not exist' in p.stderr:
            values.append(None)
        else:
            raise RuntimeError(p.stderr.strip())
    return values

def set_key(index, value):
    if value is None:
        if read()[index] is None:
            return
        command = ['delete', '-g', KEYS[index]]
    else:
        command = ['write', '-g', KEYS[index], '-int', str(value)]
    subprocess.run(['defaults', '-currentHost', *command], check=True, timeout=10)

class Preferences:
    """Track each successfully written key so a partial write can be rolled back.
    If an external edit is detected, preserve it and leave the recovery file.
    """
    def __init__(self, reader=read, setter=set_key):
        self.reader, self.setter = reader, setter
        self.before = list(reader())
        self.expected = list(self.before)

    def write(self, values):
        for index, value in enumerate(values):
            if self.reader() != self.expected:
                raise RuntimeError('Concurrent setting change; not overwriting it')
            previous = list(self.expected)
            self.expected[index] = value
            try:
                self.setter(index, value)
            except BaseException:
                if self.reader() == previous:
                    self.expected = previous
                raise
            if self.reader() != self.expected:
                raise RuntimeError('Preference readback differs')

    def restore(self):
        self.write(self.before)

def audit(executable):
    result = subprocess.run([executable, '--audit'], capture_output=True, text=True, timeout=30, check=True)
    rows = json.loads(result.stdout)
    if not isinstance(rows, list) or not rows:
        raise RuntimeError('No measurements')
    return rows

def refresh(executable):
    result = subprocess.run([executable, '--refresh-system'], timeout=20, capture_output=True, text=True)
    if result.returncode not in (0, 1):
        raise RuntimeError(result.stderr or 'Refresh executable failed')
    print(result.stdout.strip(), file=sys.stderr)
    time.sleep(3)
    return result.stdout.strip() if result.returncode else None

def compare(snapshots):
    counts = [Counter(r['identity'] for r in s) for s in snapshots]
    identities = set.union(*(set(c) for c in counts))
    rows = []
    for identity in sorted(identities):
        samples = [next((r for r in s if r['identity'] == identity), None) for s in snapshots]
        valid = all(c[identity] == 1 for c in counts) and 'unknown:' not in identity and all(r and not r['obscured'] for r in samples)
        widths = [r['width'] if r else None for r in samples]
        neighbors = [r.get('nextIdentity') if r else None for r in samples]
        same_neighbor = valid and neighbors[0] and len(set(neighbors)) == 1 and 'unknown:' not in neighbors[0]
        if same_neighbor:
            same_neighbor = all(c[neighbors[0]] == 1 and not next(r for r in s if r['identity'] == neighbors[0])['obscured'] for c,s in zip(counts,snapshots))
        gaps = [r.get('gapAfter') for r in samples] if same_neighbor else None
        changed = valid and (max(widths)-min(widths) > .5 or (gaps and None not in gaps and max(gaps)-min(gaps) > .5))
        rows.append({'item': next(r['name'] for r in samples if r), 'widths_0_8_24': widths,
                     'gaps_0_8_24': gaps, 'result': 'unmeasurable' if not valid else 'geometry_changed' if changed else 'geometry_unchanged'})
    return rows

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('executable')
    parser.add_argument('--run', action='store_true', help='authorize temporary settings changes and system-item refresh')
    args = parser.parse_args()
    initial = audit(args.executable)  # Permission and format checks BEFORE writes.
    if not args.run:
        print(json.dumps(initial, ensure_ascii=False, indent=2))
        return
    preferences = Preferences()
    recovery = Path(__file__).resolve().parents[1] / '_project/tmp/test/menu-spacing/layout/preferences.json'
    recovery.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive create: never overwrite evidence of an interrupted previous run.
    with recovery.open('x') as file:
        os.chmod(recovery, 0o600)
        json.dump(preferences.before, file)
        file.flush()
        os.fsync(file.fileno())
    def interrupted(signum, frame):
        raise InterruptedError(f'Interrupted by signal {signum}')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    snapshots = []
    warnings = []
    try:
        for value in (0, 8, 24):
            preferences.write([value, max(2, min(value - 2, 10)) if value < 16 else None])
            warnings.append(refresh(args.executable))
            snapshots.append(audit(args.executable))
        print(json.dumps({'settings': [0,8,24], 'refresh_warnings': warnings, 'items': compare(snapshots),
              'limits': 'Geometry changes are not proof of padding changes. User apps were not relaunched. Unknown, duplicate, missing or obscured items are unmeasurable.'}, ensure_ascii=False, indent=2))
    finally:
        try:
            preferences.restore()
            refresh(args.executable)
            if read() != preferences.before:
                raise RuntimeError('Restore readback differs')
        except BaseException:
            print(f'Recovery retained at {recovery}; original values: {preferences.before}', file=sys.stderr)
            raise
        recovery.unlink()
        print('RESTORED: original preferences verified', file=sys.stderr)

if __name__ == '__main__':
    main()
