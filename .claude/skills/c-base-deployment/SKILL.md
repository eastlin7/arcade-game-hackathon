---
name: c-base-deployment
description: Compile and deploy this game to the c-base gamejam server (AggroBoulder folder). Use when the user asks to deploy, ship, upload, or push the game to the server/cabinet.
---

# c-base deployment

Deploy = run the repo's deploy script:

```bash
./deploy.sh
```

It compiles locally (re-exports root `game.pck`, builds real Linux x86_64 binary
into `build/game.x86_64` — root `game.x86_64` is the mac dev wrapper, never ship
or overwrite it), then uploads to the gamejam server:

- Server: `http://172.31.78.116:2026` (copyparty HTTP server — NOT real sftp;
  ssh/sftp clients get connection reset)
- Target folder: `/games/AggroBoulder/`
- Auth: user `gamejam`, password `gamejam` (HTTP basic auth)
- Overwrite requires DELETE-then-PUT; a plain re-PUT makes copyparty create
  timestamp-suffixed duplicate files instead of replacing

Files shipped: `game.x86_64` (Linux build), `game.pck`, `game.json`, and
`icon.png` / `screenshot.png` / `preview.ogv` when present at repo root.

Verify after deploy (script prints this listing itself):

```bash
curl -s -u gamejam:gamejam "http://172.31.78.116:2026/games/AggroBoulder/?ls"
```

## Troubleshooting

**If the server is unreachable (connect timeout, "couldn't connect to host",
curl exit 7/28), tell the user: the gamejam server is on the c-base network —
they need to be on the c-base wifi (or VPN into it) for 172.31.78.116 to be
reachable.** Quick check: `nc -z -G 5 172.31.78.116 2026`.

Other failures:
- Export errors → Linux export templates missing for the local Godot version
  (`~/Library/Application Support/Godot/export_templates/`).
- HTTP 401/403 → credentials or account perms changed on the server.
- Duplicate `game.*-<timestamp>-*` files on server → an upload bypassed the
  DELETE-then-PUT flow; delete the suffixed files and re-run `./deploy.sh`.
