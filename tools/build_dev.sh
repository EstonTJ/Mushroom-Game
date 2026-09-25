#!/bin/sh
# Builds the game into docs/dev/ -> https://estontj.github.io/Mushroom-Game/dev/
# The dev site keeps its own save, so testing never touches live progress.
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Users/estontaylor/Downloads/Godot.app/Contents/MacOS/Godot}"
mkdir -p docs/dev
"$GODOT" --headless --path . --export-release "Web" docs/dev/index.html
echo "Dev build ready in docs/dev (version $(grep -o 'VERSION := "[^"]*"' scripts/data.gd | cut -d'"' -f2))."
