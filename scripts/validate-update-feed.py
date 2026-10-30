#!/usr/bin/env python3
"""Reject mismatched release metadata and verify the archive against the app's public key."""
import argparse
import plistlib
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path


def validate(app, archive, feed, tag, repository):
    with (app / 'Contents/Info.plist').open('rb') as source:
        info = plistlib.load(source)
    version = info['CFBundleShortVersionString']
    build = str(info['CFBundleVersion'])
    if tag != 'v' + version:
        raise ValueError('Release tag does not match the application version')
    ns = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
    items = ET.parse(feed).getroot().findall('./channel/item')
    if len(items) != 1:
        raise ValueError('Expected one release in the freshly generated feed')
    item = items[0]
    if item.findtext(ns + 'version') != build or item.findtext(ns + 'shortVersionString') != version:
        raise ValueError('Feed version/build does not match the application')
    enclosure = item.find('enclosure')
    if enclosure is None:
        raise ValueError('Missing update archive')
    expected = f'https://github.com/{repository}/releases/download/{tag}/{archive.name}'
    if enclosure.get('url') != expected or enclosure.get('length') != str(archive.stat().st_size):
        raise ValueError('Archive URL/length does not match the published artifact')
    signature = enclosure.get(ns + 'edSignature')
    public_key = info.get('SUPublicEDKey')
    if not signature or not public_key:
        raise ValueError('Missing update signature or embedded public key')
    subprocess.run(['swift', str(Path(__file__).with_name('verify-update-signature.swift')),
                    public_key, signature, str(archive)], check=True)
    print(f'PASS release feed matches {version} ({build}) and the signed archive')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['app', 'archive', 'feed']:
        parser.add_argument('--' + name, required=True, type=Path)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--repository', required=True)
    args = parser.parse_args()
    validate(args.app, args.archive, args.feed, args.tag, args.repository)
