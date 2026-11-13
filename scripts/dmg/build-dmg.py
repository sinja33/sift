"""Builds the disk image with dmgbuild, but links the background picture with a bookmark made by macOS itself.

dmgbuild writes that bookmark with its own Python code. Finder on macOS 26 does not resolve it and shows the
plain default background, while a bookmark from macOS's bookmark API (the one Finder uses) works.

    python build-dmg.py <bookmark helper> <settings.py> <app> <output.dmg>
"""
import subprocess
import sys

import dmgbuild.core as core
from mac_alias import Bookmark

helper, settings_file, app, output = sys.argv[1:5]


def bookmark_for_file(path):
    data = subprocess.run([helper, path], check=True, capture_output=True).stdout
    return Bookmark.from_bytes(data)


core.Bookmark.for_file = staticmethod(bookmark_for_file)
core.build_dmg(output, "Sift", settings_file=settings_file, defines={"app": app})
