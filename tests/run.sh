#!/bin/sh
# PocketOS validation: syntax-check every file, then run the headless suite.
set -e
cd "$(dirname "$0")/.."
for f in src/*.lua tests/*.lua; do
  luajit -b "$f" /dev/null || { echo "SYNTAX FAIL: $f"; exit 1; }
done
echo "syntax OK"
luajit tests/run.lua
