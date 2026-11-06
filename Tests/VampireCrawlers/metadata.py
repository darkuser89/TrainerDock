#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Read original IL2CPP v31 metadata without loading or changing the game.

Format reference: Perfare/Il2CppDumper, MetadataClass.cs (v31 records).
This tool emits inspection data to stdout; it never produces a game assembly.
"""
import argparse
from pathlib import Path
import struct


class Metadata:
    def __init__(self, path):
        self.data = Path(path).read_bytes()
        if struct.unpack_from('<II', self.data) != (0xFAB11BAF, 31):
            raise ValueError('Only the inspected metadata format v31 is supported.')
        self.strings = self.table(24, 1)
        self.fields = self.table(96, 12)
        self.methods = self.table(48, 36)
        self.parameters = self.table(88, 12)
        self.types = self.table(160, 88)
        self.images = self.table(168, 40)

    def table(self, header, stride):
        offset, size = struct.unpack_from('<II', self.data, header)
        if size % stride or offset < 256 or offset + size > len(self.data):
            raise ValueError(f'Invalid metadata table at header {header}.')
        return offset, size // stride

    def string(self, index):
        start, length = self.strings
        if not 0 <= index < length:
            raise ValueError('Invalid metadata string index.')
        end = self.data.index(b'\0', start + index, start + length)
        return self.data[start + index:end].decode('utf-8')

    def image(self, number):
        values = struct.unpack_from('<10I', self.data, self.images[0] + number * 40)
        return self.string(values[0]), values[2], values[3]

    def type(self, number):
        at = self.types[0] + number * 88
        values = struct.unpack_from('<16i8H2I', self.data, at)
        namespace = self.string(values[1])
        return dict(index=number, name=self.string(values[0]), namespace=namespace,
                    field=values[8], method=values[9], method_count=values[16],
                    field_count=values[18], token=values[-1], byval=values[2])

    def describe(self, t):
        lines = [f"{t['namespace']}.{t['name']} (type {t['index']}, token {t['token']:08x})"]
        for number in range(t['field'], t['field'] + t['field_count']):
            name, native_type, token = struct.unpack_from('<IiI', self.data, self.fields[0] + number * 12)
            lines.append(f'  field {self.string(name)} : type#{native_type} [{token:08x}]')
        for number in range(t['method'], t['method'] + t['method_count']):
            m = struct.unpack_from('<7i4H', self.data, self.methods[0] + number * 36)
            parameters = []
            for p in range(m[4], m[4] + m[-1]):
                name, _, native_type = struct.unpack_from('<IIi', self.data, self.parameters[0] + p * 12)
                parameters.append(f'{self.string(name)}:type#{native_type}')
            lines.append(f"  method {self.string(m[0])}({', '.join(parameters)}) -> type#{m[2]} [{m[6]:08x}]")
        return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('metadata', type=Path)
    parser.add_argument('names', nargs='*')
    parser.add_argument('--image', default='Assembly-CSharp.dll')
    parser.add_argument('--list', action='store_true')
    args = parser.parse_args()
    metadata = Metadata(args.metadata)
    for i in range(metadata.images[1]):
        image, first, count = metadata.image(i)
        if image != args.image:
            continue
        for n in range(first, first + count):
            t = metadata.type(n)
            full = t['namespace'] + '.' + t['name']
            if args.names and not any(name.casefold() in full.casefold() for name in args.names):
                continue
            print(full if args.list else metadata.describe(t))


if __name__ == '__main__':
    main()
