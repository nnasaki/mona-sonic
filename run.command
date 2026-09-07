#!/bin/zsh
cd -- "${0:A:h}"
if command -v godot >/dev/null 2>&1; then
  exec godot --path "$PWD" "$@"
else
  exec /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" "$@"
fi
