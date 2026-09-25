#!/bin/sh
# Copies the tested dev build (docs/dev/) to the live site (docs/) unchanged,
# so exactly what was tested goes live. -> https://estontj.github.io/Mushroom-Game/
set -e
cd "$(dirname "$0")/.."
[ -f docs/dev/index.html ] || { echo "No dev build in docs/dev. Run tools/build_dev.sh first."; exit 1; }
for f in docs/dev/*; do
	[ -f "$f" ] && cp "$f" docs/
done
echo "Live site now has the dev build. Commit and push to publish."
