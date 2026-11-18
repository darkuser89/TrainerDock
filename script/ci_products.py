#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Carry one immutable source/baseline plan across isolated CI product jobs.

Build jobs have read-only repository access. Only the ordered publishers mutate
releases/catalogs. No force rebuilds, source copies, game starts or signing keys.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import plistlib
import re
import stat
import subprocess
import zipfile
import urllib.request

import trainer_distribution as distribution
from ci_version import choose_version

ROOT = Path(__file__).resolve().parents[1]
BUILD_ROOT = Path.home() / 'Library/Developer/TrainerDock'
MAX_ARCHIVE = 200 * 1024 * 1024


def digest(value):
    return hashlib.sha256(distribution.json_bytes(value)).hexdigest()


def read_json(path):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 8 * 1024 * 1024:
        raise ValueError('Fehlende oder ungültige CI-Metadaten: ' + path.name)
    return json.loads(path.read_bytes())


def git_commit():
    actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    expected = os.environ.get('GITHUB_SHA', actual)
    if not re.fullmatch(r'[0-9a-f]{40}', actual) or actual != expected:
        raise ValueError('Checkout und angeforderter CI-Commit stimmen nicht überein.')
    return actual


def may_publish():
    return (os.environ.get('GITHUB_EVENT_NAME') != 'pull_request' and
            (os.environ.get('GITHUB_REF') == 'refs/heads/main' or
             re.fullmatch(r'refs/tags/v(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)',
                          os.environ.get('GITHUB_REF', '')) is not None))


def validate_scope(plan, mode, requested):
    if mode not in ('auto', 'launcher', 'trainers'):
        raise ValueError('Unbekannte Produktauswahl.')
    selected = [part.strip() for part in requested.split(',')] if requested.strip() else []
    if any(not distribution.TOKEN.fullmatch(part) for part in selected):
        raise ValueError('Trainer bitte als kommagetrennte stabile Modul-IDs angeben.')
    if set(selected) - set(plan['allModules']):
        raise ValueError('Unbekannte oder nicht freigegebene Trainer-ID.')
    changed = {item['id'] for item in plan['modules']}
    if mode != 'trainers' and selected:
        raise ValueError('Trainer-IDs sind nur bei der Trainerauswahl zulässig.')
    if mode == 'launcher' and changed:
        raise ValueError('Weitere Trainer sind tatsächlich betroffen: ' + ', '.join(sorted(changed)) +
                         '. Automatisch bauen; den vollständigen Plan nicht abschneiden.')
    if mode == 'trainers':
        if plan['launcher']['changed']:
            raise ValueError('Auch die App ist tatsächlich geändert. Automatischen vollständigen Plan verwenden.')
        if selected and changed - set(selected):
            raise ValueError('Weitere Trainer/Abhängigkeiten sind betroffen: ' + ', '.join(sorted(changed - set(selected))))
    # Unchanged requested products are deliberately NOT added to the plan.


def prepare(root, mode, requested):
    token = os.environ.get('GITHUB_TOKEN') or os.environ.get('GH_TOKEN')
    previous = distribution.fetch_catalog(token)
    tags = subprocess.check_output(['git', 'ls-remote', '--tags', 'origin'], cwd=ROOT, text=True)
    reserved = {}
    names = [line.split('\t', 1)[1].removeprefix('refs/tags/') for line in tags.splitlines() if '\t' in line]
    for name in names:
        match = re.fullmatch(r'trainer-([a-z0-9]+(?:-[a-z0-9]+)*)-v([0-9.]+)', name)
        if match and distribution.VERSION.fullmatch(match[2]):
            reserved.setdefault(match[1], []).append(match[2])
    plan = distribution.plan(previous, ROOT, reserved=reserved)
    validate_scope(plan, mode, requested)
    current = ''
    if plan['launcher']['changed']:
        configured = re.search(r'^MARKETING_VERSION = (\S+)$', (ROOT/'Config/TrainerDock.xcconfig').read_text(), re.M)[1]
        current = choose_version(configured, os.environ.get('REF_TYPE', 'branch'), os.environ.get('REF_NAME', ''), names)
    context = dict(schemaVersion=1, commit=git_commit(), planSHA256=digest(plan),
                   baselineSHA256=digest(previous), launcherVersion=current)
    for name, value in [('baseline.json', previous), ('plan.json', plan), ('ci-context.json', context)]:
        distribution.write_json(root/'Distribution'/name, value)
    distribution.write_json(root/'Catalog/catalog.json', previous)
    outputs = dict(launcher_changed=str(plan['launcher']['changed']).lower(),
                   modules=json.dumps([item['id'] for item in plan['modules']], separators=(',', ':')),
                   any_changed=str(plan['launcher']['changed'] or bool(plan['modules']) or plan['catalogChanged']).lower(),
                   version=current)
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a') as stream:
            for key, value in outputs.items():
                stream.write(key+'='+value+'\n')
    summary = ('### Geprüfter Produktplan\n\nApp: '+(current or 'unverändert')+
               '\n\nTrainer: '+(', '.join(item['id']+' '+item['version'] for item in plan['modules']) or 'keine')+
               '\n\nUnveränderte Produkte werden weder gebaut noch veröffentlicht.\n')
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as stream:
            stream.write(summary)
    print(summary)


def read_state(root):
    previous = distribution.validate_catalog(read_json(root/'Distribution/baseline.json'))
    plan, context = (read_json(root/'Distribution'/name) for name in ('plan.json', 'ci-context.json'))
    if (context.get('schemaVersion') != 1 or plan.get('schemaVersion') != 1 or
        context.get('commit') != git_commit() or context.get('planSHA256') != digest(plan) or
        context.get('baselineSHA256') != digest(previous) or plan.get('baselineSHA256') != digest(previous)):
        raise ValueError('Plan, bestätigter Ausgangskatalog und Quellcommit passen nicht zusammen.')
    ids = [item['id'] for item in plan['modules']]
    if len(set(ids)) != len(ids) or any(not distribution.TOKEN.fullmatch(key) for key in ids):
        raise ValueError('Ungültige oder doppelte Trainer im Bauplan.')
    for item in plan['modules']:
        source = ROOT/'Modules'/item['id']
        distribution.version(item['version'])
        if (distribution.module_fingerprint(source) != item['fingerprint'] or
            distribution.module_content_fingerprint(source) != item['contentFingerprint']):
            raise ValueError('Trainerquellen weichen vom bestätigten CI-Plan ab: '+item['id'])
    if plan['launcher']['changed']:
        distribution.version(context['launcherVersion'])
        if (distribution.launcher_fingerprint() != plan['launcher']['fingerprint'] or
            distribution.launcher_content_fingerprint() != plan['launcher']['contentFingerprint']):
            raise ValueError('Appquellen weichen vom bestätigten CI-Plan ab.')
    return previous, plan, context


def module_item(plan, identifier):
    items = [item for item in plan['modules'] if item['id'] == identifier]
    if len(items) != 1:
        raise ValueError('Trainer gehört nicht zum Änderungsplan; kein erzwungener Build: '+identifier)
    return items[0]


def performance(identifier):
    suites = [('Tests/Managed/RunPerformanceTests.py', {'the-long-dark', 'vampire-crawlers', 'terraria'}, []),
              ('Tests/UnrealPerformance/RunPerformanceTests.py', {'frostpunk-2', 'inzoi', 'stray'}, []),
              ('Tests/NativePerformance/RunPerformanceTests.py', {'control', 'no-mans-sky', 'resident-evil-2',
               'resident-evil-3', 'resident-evil-4', 'resident-evil-7', 'resident-evil-village', 'turok', 'turok-2'}, ['--configuration', 'Release'])]
    for source, identifiers, extra in suites:
        if identifier in identifiers:
            run(source, *extra, '--modules', identifier)
    if identifier in ('escape-from-duckov', 'vampire-survivors'):
        run('Tests/Managed/ManagedHotPathTests.py')


def run(source, *arguments):
    subprocess.run(['/usr/bin/python3', '-B', str(ROOT/source), *map(str, arguments)], cwd=ROOT, check=True)


def managed_input(identifier):
    from managed import verified_managed_image
    lock = json.loads((ROOT/'Config/ManagedImages.json').read_text())
    if identifier not in lock['modules']:
        return
    destination = Path(os.environ['TRAINERDOCK_MANAGED_IMAGES'])
    destination.mkdir(parents=True, exist_ok=True)
    entry = lock['modules'][identifier]
    url = distribution.BASE_URL+lock['release']+'/'+entry['file']
    with urllib.request.urlopen(url, timeout=60) as response:
        data = response.read(1024*1024+1)
    (destination/entry['file']).write_bytes(data)
    module = ROOT/'Modules'/identifier
    verified_managed_image(destination, module, json.loads((module/'Module.json').read_text()),
                           json.loads((module/'Build.json').read_text()))


def build_trainer(root, identifier):
    _, plan, context = read_state(root)
    item = module_item(plan, identifier)
    managed_input(identifier)
    run('script/build.py', '--module', identifier, '--configuration', 'Release', '--build-dir', root)
    performance(identifier)
    subprocess.run(['git', 'diff', '--exit-code', '--', 'TrainerDock.xcodeproj'], cwd=ROOT, check=True)
    record = distribution.package_module(root, item)
    receipt = read_json(root/'BuildFingerprints'/(identifier+'.json'))
    proof = dict(context=context, fingerprint=receipt['fingerprint'], sha256=receipt['sha256'], recordSHA256=digest(record))
    distribution.write_json(root/'Distribution/Trainers'/f'{identifier}-{item["version"]}.build.json', proof)
    return record


def archive_bytes(path, record):
    if (path.is_symlink() or not path.is_file() or type(record.get('size')) is not int or
        not 0 < record['size'] <= MAX_ARCHIVE or path.stat().st_size != record['size']):
        raise ValueError('Fehlendes oder ungültiges Produktartefakt.')
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != record.get('sha256'):
        raise ValueError('Produktartefakt stimmt nicht mit dem Buildbeleg überein.')
    return data


def archive_members(archive, prefix, expected=None):
    members = {}
    total = 0
    if len(archive.infolist()) > 8192:
        raise ValueError('Zu viele Archiveinträge.')
    for entry in archive.infolist():
        name = entry.filename
        parts = name.rstrip('/').split('/')
        mode = stat.S_IFMT(entry.external_attr >> 16)
        if ('\\' in name or any(part in ('', '.', '..') for part in parts) or
            mode not in (0, stat.S_IFREG, stat.S_IFDIR) or entry.flag_bits & 1 or
            name in members or entry.file_size < 0 or
            (mode == stat.S_IFDIR and not entry.is_dir()) or
            (mode == stat.S_IFREG and entry.is_dir())):
            raise ValueError('Ungültiger Archiveintrag.')
        total += entry.file_size
        if total > MAX_ARCHIVE:
            raise ValueError('Entpacktes Produkt ist zu groß.')
        if name.startswith('__MACOSX/'):
            continue
        if not ((name == prefix.rstrip('/') and entry.is_dir()) or name.startswith(prefix)):
            raise ValueError('Fremdes Produkt im Artefakt.')
        members[name] = entry
    if expected is not None and set(members) != set(expected):
        raise ValueError('Trainerartefakt enthält nicht exakt die vier Produktdateien.')
    return members


def trainer_records(root, plan, context):
    directory = root/'Distribution/Trainers'
    expected_files = set()
    records = {}
    for item in plan['modules']:
        identifier = item['id']; stem = identifier+'-'+item['version']
        expected_files.update(stem+suffix for suffix in ('.zip', '.json', '.build.json'))
        record = read_json(directory/(stem+'.json'))
        proof = read_json(directory/(stem+'.build.json'))
        distribution.validate_catalog(dict(schemaVersion=1, moduleABI=1, modules=[dict(id=identifier, name=item['name'], versions=[record])]))
        if (record['version'] != item['version'] or record['fingerprint'] != item['fingerprint'] or
            record.get('contentFingerprint') != item['contentFingerprint'] or proof.get('context') != context or
            proof.get('fingerprint') != item['fingerprint'] or proof.get('recordSHA256') != digest(record)):
            raise ValueError('Trainerartefakt gehört zu einem anderen Auftrag/Commit.')
        source = json.loads((ROOT/'Modules'/identifier/'Module.json').read_text())
        if any(record['manifest'].get(key) != value for key, value in source.items() if key not in ('version', 'features')):
            raise ValueError('Trainerprofile passen nicht zum freigegebenen Quellstand.')
        config_source = read_json(ROOT/'Modules'/identifier/'Build.json')
        license_bytes = (ROOT/'Modules'/identifier/config_source.get('sourceRoot', 'Sources')/'LICENSE').read_bytes()
        data = archive_bytes(directory/(stem+'.zip'), record)
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            prefix = identifier+'.mhtmodule/'
            archive_members(archive, prefix, [prefix+name for name in distribution.FILES])
            manifest = json.loads(archive.read(prefix+'Module.json'))
            config = json.loads(archive.read(prefix+'TrainerConfig.json'))
            expected_config = dict(schemaVersion=1, app=dict(name=manifest['name'], bundleIdentifier='local.mht.module.'+identifier, version=item['version'], build='1'), profiles=manifest['profiles'])
            if (manifest != record['manifest'] or config != expected_config or
                archive.read(prefix+'LICENSE') != license_bytes or
                hashlib.sha256(archive.read(prefix+'Trainer.dylib')).hexdigest() != proof.get('sha256')):
                raise ValueError('Trainerbytes, Profile oder finaler CodeSign-Beleg weichen ab.')
        records[identifier] = record
    actual = {p.name for p in directory.iterdir()} if directory.exists() else set()
    if actual != expected_files:
        raise ValueError('Fehlende oder unerwartete Trainerartefakte; keine Teilveröffentlichung.')
    return records


def publish_trainers(root):
    previous, plan, context = read_state(root)
    records = trainer_records(root, plan, context)  # Validate every job BEFORE any write.
    if not may_publish():
        raise ValueError('Trainerveröffentlichung ist nur auf main oder einem App-Releasetag erlaubt.')
    token = os.environ.get('GITHUB_TOKEN') or os.environ.get('GH_TOKEN')
    updated = distribution.GitHub(token, context['commit']).publish_trainers(previous, records, root/'Distribution/Trainers')
    distribution.write_json(root/'Catalog/catalog.json', updated)
    distribution.write_json(root/'Distribution/trainer-records.json', records)


def build_launcher(root):
    previous, plan, context = read_state(root)
    if not plan['launcher']['changed']:
        raise ValueError('App unverändert; kein erzwungener Build.')
    catalog = root/'Catalog/catalog.json'
    if may_publish():
        distribution.read_catalog(catalog)  # Must come from the ordered trainer publisher.
    else:
        distribution.write_json(catalog, previous)  # PR previews never advertise unpublished packages.
    run('script/build.py', '--launcher-only', '--configuration', 'Release', '--build-dir', root,
        '--version', context['launcherVersion'], '--build-number', os.environ.get('GITHUB_RUN_NUMBER', '1'))
    subprocess.run(['git', 'diff', '--exit-code', '--', 'TrainerDock.xcodeproj'], cwd=ROOT, check=True)
    run('script/release.py', '--build-dir', root)
    record = read_json(root/'Distribution/launcher-record.json')
    distribution.write_json(root/'Distribution/launcher-build.json', dict(context=context, record=record,
        fingerprint=plan['launcher']['fingerprint'], contentFingerprint=plan['launcher']['contentFingerprint'],
        catalogSHA256=digest(distribution.read_catalog(catalog))))


def validate_launcher(root, plan, context, catalog):
    record = read_json(root/'Distribution/launcher-record.json')
    proof = read_json(root/'Distribution/launcher-build.json')
    if (not plan['launcher']['changed'] or record.get('version') != context['launcherVersion'] or
        proof.get('context') != context or proof.get('record') != record or
        proof.get('fingerprint') != plan['launcher']['fingerprint'] or
        proof.get('contentFingerprint') != plan['launcher']['contentFingerprint'] or proof.get('catalogSHA256') != digest(catalog)):
        raise ValueError('Appartefakt passt nicht zum geprüften Quellstand und Katalog.')
    data = archive_bytes(root/'Distribution/TrainerDock-macOS-arm64.zip', record)
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        prefix = 'TrainerDock.app/Contents/'
        members = archive_members(archive, 'TrainerDock.app/')
        if any('.mhtmodule/' in name or name.endswith('/Trainer.dylib') for name in members):
            raise ValueError('Appartefakte dürfen keine Trainer enthalten.')
        info = plistlib.loads(archive.read(prefix+'Info.plist'))
        build = json.loads(archive.read(prefix+'Resources/BUILD.json'))
        if (info.get('CFBundleShortVersionString') != record['version'] or info.get('LSMinimumSystemVersion') != '27.0' or
            build.get('commit') != context['commit'] or build.get('version') != record['version'] or
            build.get('architecture') != 'arm64' or build.get('modules') != [] or build.get('moduleABI') != 1 or
            digest(distribution.validate_catalog(json.loads(archive.read(prefix+'Resources/TrainerCatalog.json')))) != digest(catalog)):
            raise ValueError('Appinhalt, Quellcommit oder bestätigter Offlinekatalog weicht ab.')
        for name in ('MacOS/TrainerDock', 'MacOS/TrainerDockEpicBroker', '_CodeSignature/CodeResources'):
            if not archive.read(prefix+name):
                raise ValueError('Unvollständiges versiegeltes Appartefakt.')
    sums = (root/'Distribution/SHA256SUMS').read_text()
    if sums != record['sha256']+'  TrainerDock-macOS-arm64.zip\n':
        raise ValueError('App-Prüfsummendatei passt nicht zum Paket.')


def publish_launcher(root):
    _, plan, context = read_state(root)
    catalog = distribution.read_catalog(root/'Catalog/catalog.json')
    validate_launcher(root, plan, context, catalog)
    if not may_publish():
        raise ValueError('Appveröffentlichung ist hier nicht freigegeben.')
    token = os.environ.get('GITHUB_TOKEN') or os.environ.get('GH_TOKEN')
    if digest(distribution.fetch_catalog(token)) != digest(catalog):
        raise ValueError('Bestätigter Katalog wurde während des App-Builds geändert; neu planen.')
    # The existing immutable release/upload/catalog transaction stays authoritative.
    distribution.write_json(root/'Distribution/trainer-records.json', {})
    run('script/trainer_distribution.py', 'publish-launcher', '--build-dir', root, '--commit', context['commit'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('init', 'plan', 'build-trainer', 'publish-trainers', 'build-launcher', 'publish-launcher'))
    parser.add_argument('--build-dir', default=str(BUILD_ROOT))
    parser.add_argument('--module')
    args = parser.parse_args()
    root = distribution.external_path(args.build_dir)
    distribution.prepare_build_root(root)
    if args.action == 'init':
        return
    if args.action == 'plan':
        prepare(root, os.environ.get('BUILD_MODE', 'auto'), os.environ.get('REQUESTED_MODULES', ''))
    elif args.action == 'build-trainer':
        build_trainer(root, args.module or '')
    else:
        {'publish-trainers': publish_trainers, 'build-launcher': build_launcher,
         'publish-launcher': publish_launcher}[args.action](root)


if __name__ == '__main__':
    main()
