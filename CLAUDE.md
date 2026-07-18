# arcade-game — c-base Arcade cabinet game

A Godot game for the c-base arcade cabinet. It is **launched by the c-base Arcade Launcher**
(sibling repo: `../GD_ArcadeLauncher`) — this folder must always satisfy the launcher's
game contract ("c-base Arcade Upload Spec v1.0", see `../GD_ArcadeLauncher/GAME_SPEC.md`).

## How this game gets launched

- The launcher scans a games directory, finds folders containing an executable + `.pck`,
  and spawns the game with: `OS.create_process("<exec>", ["--main-pack", "<pck>"])`.
- The launcher stays alive in the background. When this game's process exits (or crashes),
  the launcher regains focus. The game must therefore be able to **quit itself**.
- Production (Ubuntu cabinet): games live in `/arcade/games/<folder>/`, uploaded via SFTP.
- Local dev (this Mac): the launcher falls back to scanning `~/Code` (the repo's parent
  directory) when `/arcade/games` doesn't exist — so **this folder is discovered directly**.
  Folder name = `game_id` (`arcade-game`).

## Folder contract (MUST keep valid)

Required at folder root — if either is missing, the launcher hides the game:

| File | Purpose |
|------|---------|
| `game.x86_64` (or `*.AppImage`) | Executable. On the cabinet: real Linux x86_64 Godot export, `chmod +x`. Locally: a bash wrapper that runs `~/Downloads/Godot.app/Contents/MacOS/Godot "$@"` — do not break it. |
| `game.pck` | Exported Godot pack of this project. Must stay in sync with the source. |

Recommended (graceful fallbacks if missing):

| File | Purpose |
|------|---------|
| `game.json` | `{title, author, description, players (int), year (int)}`. Missing/invalid → folder name used as title. |
| `preview.ogv` | 5–15s gameplay clip, 1280x720+, Ogg Theora preferred (`.mp4` support varies). |
| `screenshot.png` | 1920x1080 fallback image when no preview video. |
| `icon.png` | 128x128 list icon. |

## Input contract (MANDATORY)

The cabinet has arcade joysticks + buttons (USB HID). The game MUST implement these
Godot InputMap actions:

- `ui_up`, `ui_down`, `ui_left`, `ui_right` — joystick/D-pad movement
- `ui_accept` — Button 1: start/confirm
- `ui_cancel` — Button 2: back/pause
- **`ui_exit` — MANDATORY: immediately quit and return to launcher:**

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_exit"):
        get_tree().quit()
```

Without `ui_exit`, players get stuck in the game — this is the #1 rule.
Note: `ui_exit` is a custom action; it must be defined in this project's `project.godot`
`[input]` section (currently bound to Esc), not assumed from Godot defaults.

## Project rules

- Godot 4.x (built with 4.6.2 locally; launcher targets 4.5+). GL Compatibility renderer
  (cabinet may have an older GPU).
- Always fullscreen (`display/window/size/mode=3`).
- Main scene: `Main.tscn` (+ `Main.gd`). Keep `run/main_scene` pointing at it.
- Show on-screen button prompts (e.g. "Press Button 1 to start") — arcade players get no manual.
- Keep assets small; fast load times matter in an arcade.
- Reasonable audio volume; cabinet shares one speaker set.
- If multiplayer: set `players` in `game.json` accordingly. (No per-player device
  convention exists yet in the launcher spec — coordinate before adding P2 input.)

## High scores (optional)

Write to `/arcade/scores/<game_id>.json` (game_id = folder name) as a JSON array
`[{"name": "AAA", "score": 10000}, ...]`, sorted descending, keep top 10. The launcher
displays these per-game in its details panel. On this dev machine `/arcade` doesn't
exist — guard score writes with a directory-exists check.

## Build / test workflow

1. Edit source (`Main.tscn`, `Main.gd`, `project.godot`).
2. Re-export the pack (headless, from this folder):
   ```bash
   ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --import .
   ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-pack Linux game.pck
   ```
   (Uses the `Linux` preset in `export_presets.cfg`.)
3. Quick standalone test: `./game.x86_64 --main-pack game.pck`
4. Full test: run the launcher project (`../GD_ArcadeLauncher`) in Godot — this game
   appears in the list; launch it; verify `ui_exit` (Esc) returns to the launcher.
5. Cabinet deploy: export a real Linux x86_64 build (needs Linux export templates),
   `chmod +x`, upload folder via SFTP/rsync to `/arcade/games/arcade-game/`. The
   launcher hot-reloads via inotify — no restart needed.

## Pre-ship checklist

- [ ] `game.x86_64` + `game.pck` present, exec bit set
- [ ] `ui_exit` quits the game
- [ ] All `ui_*` actions work with joystick AND keyboard
- [ ] Fullscreen, no window decorations
- [ ] `game.json` valid JSON
- [ ] Tested end-to-end through the launcher (launch → play → exit → back to menu)
