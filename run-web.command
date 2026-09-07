#!/bin/zsh
set -e
cd -- "${0:A:h}"
mkdir -p build/web
touch build/.gdignore
./run.command --headless --editor --import --quit
./run.command --headless --export-release Web build/web/index.html
print -r -- "Open http://127.0.0.1:${1:-8765}/ — Ctrl+C stops the server."
exec python3 -m http.server "${1:-8765}" --bind 127.0.0.1 --directory build/web
