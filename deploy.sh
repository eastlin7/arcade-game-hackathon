#!/usr/bin/env bash
# Compile locally, then ship this folder's files to the gamejam server
# (copyparty HTTP, not real sftp): http://172.31.78.116:2026/games/AggroBoulder/
#
# Root game.pck is re-exported so the repo stays in sync (launcher contract).
# Root game.x86_64 is the MAC DEV WRAPPER and must not be shipped or touched;
# a real Linux x86_64 binary is compiled locally into build/ and shipped as
# game.x86_64 instead.
set -euo pipefail
cd "$(dirname "$0")"

GODOT="$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
SERVER="http://172.31.78.116:2026"
REMOTE_DIR="games/AggroBoulder"
AUTH="gamejam:gamejam"

echo "==> Importing resources"
"$GODOT" --headless --import . >/dev/null

echo "==> Exporting root game.pck (keeps repo in sync)"
"$GODOT" --headless --path . --export-pack Linux game.pck

echo "==> Compiling Linux x86_64 binary"
mkdir -p build
"$GODOT" --headless --path . --export-release Linux build/game.x86_64 >/dev/null
chmod +x build/game.x86_64
[ -s build/game.x86_64 ] || { echo "ERROR: no Linux binary produced"; exit 1; }
[ -s game.pck ]          || { echo "ERROR: no game.pck produced"; exit 1; }

echo "==> Ensuring remote folder exists"
curl -sf -u "$AUTH" -d 'act=mkdir' -d 'name=AggroBoulder' "$SERVER/games/" >/dev/null || true

upload() { # upload <localfile> <remotename> — delete first, else copyparty dedups with suffix
  echo "    $2"
  curl -s -o /dev/null -u "$AUTH" -X DELETE "$SERVER/$REMOTE_DIR/$2"
  curl -sf -u "$AUTH" -T "$1" "$SERVER/$REMOTE_DIR/$2" >/dev/null
}

echo "==> Uploading (overwrite)"
upload build/game.x86_64 game.x86_64
upload game.pck  game.pck
upload game.json game.json
for f in icon.png screenshot.png preview.ogv; do
  [ -f "$f" ] && upload "$f" "$f"
done

echo "==> Remote listing:"
curl -s -u "$AUTH" "$SERVER/$REMOTE_DIR/?ls" | python3 -c 'import json,sys
for f in json.load(sys.stdin)["files"]:
    print("  %12d  %s" % (f["sz"], f["href"]))'
echo "==> Done"
