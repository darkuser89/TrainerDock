#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Read-only inspection of the user's exact original; no game execution."""
from pathlib import Path
import sys
import importlib.util
_spec=importlib.util.spec_from_file_location('trainerdock_native_image',Path(__file__).resolve().parents[1]/'Frostpunk2/Inspect.py')
_image=importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_image)
Image=_image.Image
IMAGE=Path('/Volumes/Mac Games/SteamLibrary/steamapps/common/inZOI/inZOI.app/Contents/MacOS/inZOI')
if __name__=='__main__':
 m=Image(IMAGE)
 for value in sys.argv[1:]:m.dis(int(value,0),192)
