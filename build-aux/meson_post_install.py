#!/usr/bin/env python3

from os import environ
from subprocess import call
import sys

if len(sys.argv) < 4:
    sys.exit("usage: meson_post_install.py <icondir> <schemadir> <appsdir>")

icon_cache_dir  = sys.argv[1]
schemadir       = sys.argv[2]
appsdir         = sys.argv[3]

if not environ.get('DESTDIR', ''):
    print('Updating icon cache...')
    call(['gtk-update-icon-cache', '-qtf', icon_cache_dir])

    print("Compiling new schemas")
    call(["glib-compile-schemas", schemadir])

    print("Updating desktop database")
    call(["update-desktop-database", appsdir])
