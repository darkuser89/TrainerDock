#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Choose a unique release version before building; never creates a tag."""
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
VERSION = r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'


def parse(value):
    match = re.fullmatch(VERSION, value)
    if not match:
        raise ValueError('Use MAJOR.MINOR.PATCH without leading zeros')
    return tuple(map(int, match.groups()))


def choose_version(configured, ref_type, ref_name, remote_tags):
    floor = parse(configured)
    if ref_type == 'tag':
        if not ref_name.startswith('v'):
            raise ValueError('Release tags must start with v')
        parse(ref_name[1:])
        return ref_name[1:]
    if ref_name != 'main':
        return configured
    used = [parse(tag[1:]) for tag in remote_tags
            if re.fullmatch('v' + VERSION, tag)]
    latest = max(used, default=(-1, -1, -1))
    version = floor if floor > latest else (latest[0], latest[1], latest[2] + 1)
    return '.'.join(map(str, version))


def main():
    text = (ROOT / 'Config/TrainerDock.xcconfig').read_text()
    match = re.search(r'^MARKETING_VERSION = (\S+)$', text, re.M)
    if not match:
        raise ValueError('Missing configured version')
    ref_type, ref_name = os.environ['REF_TYPE'], os.environ['REF_NAME']
    tags = []
    if ref_type != 'tag' and ref_name == 'main':
        # Includes orphaned tags from failed publications: never reuse their name.
        lines = subprocess.check_output(
            ['git', 'ls-remote', '--tags', 'origin'], cwd=ROOT, text=True).splitlines()
        tags = [line.split('\t', 1)[1].removeprefix('refs/tags/')
                for line in lines if '\trefs/tags/' in line]
    version = choose_version(match.group(1), ref_type, ref_name, tags)
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write(f'version={version}\ntag=v{version}\n')
    with open(os.environ['GITHUB_ENV'], 'a') as output:
        output.write(f'TRAINERDOCK_VERSION={version}\n')
        output.write('TRAINERDOCK_MANAGED_IMAGES=' + os.environ['RUNNER_TEMP'] + '/managed-images\n')
    print('Build version:', version)


if __name__ == '__main__':
    main()
