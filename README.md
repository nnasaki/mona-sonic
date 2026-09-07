# MONA · AZURE COAST

A playable Godot 4 coastal speed stage, made with local code, procedural meshes, shaders, synthesized audio and locally installed fonts. All game content is local; the browser build additionally uses Godot's official Web runtime.

## Play

Open `project.godot` in Godot 4.7 and press **F5**, or run:

```sh
./run.command
```

On other platforms with Godot 4 installed:

```sh
godot --path .
```

The default renderer is Forward+; macOS uses Metal. For an older GPU, a reduced visual fallback is available with `godot --path . --rendering-method gl_compatibility`.

## Play in a browser

Play online: **https://nnasaki.github.io/mona-sonic/**

On a phone, turn sideways and tap **LET'S ROLL**. Hold anywhere on the stage to run, slide left/right while holding to steer, and flick **up** to jump. Flick up again in the air to attack a locked target. Slide back to center the steering; lifting your finger releases acceleration and steering while preserving momentum. Use **PAUSE** to pause, restart or change settings. Keyboard and controller controls remain available.

```sh
./run-web.command
```

Open **http://127.0.0.1:8765/**. This command builds the game and keeps a local HTTP server running; Ctrl+C stops it. Pass a different port, for example `./run-web.command 9000`, if needed. The browser needs WebGL 2 and WebAssembly; keyboard and controller controls are supported. No external services or game assets are fetched by the page.

The official **Godot 4.7.2 Web export templates** are installed on this Mac. On another build machine, install the matching version's export templates in Godot first. Only `web_nothreads_debug.zip` and `web_nothreads_release.zip` are needed for this preset. To build and serve manually:

```sh
mkdir -p build/web
touch build/.gdignore
godot --headless --path . --editor --import --quit
godot --headless --path . --export-release Web build/web/index.html
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web
```

The Web preset uses a single thread and a 1280×720 Compatibility viewport, with lighting and Mona's painted face adjusted for WebGL. Screen-space reflections, ambient occlusion and temporal antialiasing remain available in the native build. Audio begins with the first click or keypress. Leaving the game pauses the run; Escape resumes it. Press **F** or the fullscreen button to request fullscreen; the browser's View menu also works when it declines the request. Browser personal bests are stored per browser and site address.

For an automatic full-stage showcase, open **http://127.0.0.1:8765/?demo=1**. This keeps the result screen open and does not write a personal best. The complete standalone site is in `build/web/`; keep its files together and serve them over HTTP instead of opening `index.html` as a local file.

| Action | Keyboard | Controller |
|---|---|---|
| Accelerate / brake | W / S or ↑ / ↓ | Left stick |
| Steer / change rails | A / D or ← / → | Left stick |
| Jump / airborne homing attack | Space | A / Cross |
| Boost | Shift | RT / R2 or RB / R1 |
| Roll / hold at low speed to charge spin dash | Ctrl | X / Square |
| Drift while steering; release for acceleration | Q or E | LT / L2 or LB / L1 |
| Pause | Esc | Start / Options |
| Restart | R | Pause menu |
| Fullscreen | F or F11 | — |
| Controls | H | Pause menu |

Menus support mouse, arrow keys / D-pad and Enter / A. The pause menu includes reduced camera motion and an audio toggle. Release acceleration to coast. Rings replenish boost, while braking, jumping, drifting and rolling retain continuous movement instead of stopping at each transition.

## The stage

One continuous **1.84 km** course links a cliffside opening, downhill run, 64 m loop, corkscrew, three ocean rails, an airborne enemy chain, sunstone ruins and tunnel, a banked vertical wall, a giant waterfall jump and the final sprint. Rings trace racing lines. Dash panels, springs, breakaway bridge slabs, birds and robot debris react as you pass. Steer right at the first fork or left entering the ruins to find two narrow elevated routes.

The playable character follows the supplied Mona Lisa Octocat reference: an oversized, softly rounded black head with low cat ears, a peach face set low on the head, simple brown oval eyes and a small smile, four short feet and a slender side tentacle with pale suction cups. The head and face contours are modeled from the reference proportions. Mona takes short, quick steps and tucks into a dark curled form for rolling and homing attacks. The procedural rig also supports breathing, blinking, jumping, landing, drifting, grinding, spring launches, stumbling and victory. The camera changes composition for the loop, rail and waterfall sections and checks native scene collisions.

The movement controller is designed around an authored boost course: distance along the stage, analog lateral motion and independent jump height are simulated against a continuous surface frame. This keeps slopes, inversions, rails and walls smooth at high speed. Falling returns you to a checkpoint; finishing shows your time, rings, speed and best homing chain. Personal bests are stored locally in Godot's `user://record.cfg`.

## Local checks

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 120 --script tests/smoke.gd
godot --headless --path . --fixed-fps 120 --quit-after 10000 -- --demo
```

The single regression script checks the surface frames, acceleration, momentum, boost, jump and landing, spin dash, drifting, both routes and merges, grinding, springs, five chained attacks, checkpoints, camera distance and finish flow. `--demo` drives a full run without changing your personal best. `--section=0` through `--section=8` starts at a landmark for inspection.

To save real rendered screenshots during a normal or demo run, create a directory and pass `--capture-dir=/absolute/path`. Headless mode is for logic checks; screenshots need the normal renderer.

## Files and local provenance

- `scripts/course.gd`: continuous course frames and elevated routes.
- `scripts/player.gd`: momentum, traversal and interactions.
- `scripts/mona.gd`: procedural Mona Lisa Octocat geometry and animation.
- `scripts/world.gd`, `shaders/`: original terrain, ocean, foliage, lighting and effects.
- `scripts/main.gd`, `scripts/hud.gd`: cameras, input, menus and race presentation.
- `scripts/audio.gd`: synthesized effects and speed-dependent wind.
- `export_presets.cfg`, `web/index.html`, `run-web.command`: Web export, loading screen and local launcher.
- `assets/generate_audio.py`: original 152 BPM music, rendered with Python's standard library. Run it to regenerate `assets/audio/coast.wav`.
- `assets/fonts/`: Arial, Arial Black and DIN Alternate Bold from this Mac's installed system fonts; their original font licenses apply.

Mona Lisa Octocat is GitHub's character. This is a locally created fan prototype, with original code, procedural meshes, shaders and music; no official character assets are included.
