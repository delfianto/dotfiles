#!/usr/bin/env python
# read /etc/os-release and store parse it as key value pairs
# https://stackoverflow.com/questions/29030135/module-to-parse-a-simple-syntax-in-python

with open("/etc/os-release") as f:
    d = {}
    for line in f:
        k,v = line.rstrip().split("=")
        if v.startswith('"'):
          v = v[1:-1]
        d[k] = v
print(d)
