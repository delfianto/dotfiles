#!/usr/bin/env python3
# python alternative for realpath in gnu coreutils
import os
import sys

print(os.path.realpath(sys.argv[1]))
