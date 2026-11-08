#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Evaluate a session-scoped probe on the observed original B2 callback.

Never starts a game, installs files, remounts a mod or invokes LuaPrint.
"""
import json
import sys
from Query import query


def evaluate(script):
    return query(dict(op='eval', script=script))


if __name__ == '__main__':
    print(json.dumps(evaluate(sys.stdin.read()),
                     ensure_ascii=False, indent=2))
