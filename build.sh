#!/bin/bash
set -e

MOD_ID="saveitemspots"
VERSION_DIR="42"

# Convert preview SVG to PNG
apt-get install -y -qq librsvg2-bin 2>/dev/null || true
rsvg-convert -w 512 -h 512 preview.svg -o preview.png

# Stage content in Workshop directory structure
rm -rf content
mkdir -p "content/mods/${MOD_ID}/${VERSION_DIR}"
cp mod.info "content/mods/${MOD_ID}/"
cp mod.info "content/mods/${MOD_ID}/${VERSION_DIR}/"
cp -r ${VERSION_DIR}/media "content/mods/${MOD_ID}/${VERSION_DIR}/"

echo "Workshop content staged: content/mods/${MOD_ID}/${VERSION_DIR}/"
