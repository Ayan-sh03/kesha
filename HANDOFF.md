# Dwaar: handoff

The source of truth is the concept bible (Dwaar Codex v0.2): five doors, the Veiled Mother, Tesu and Bindu, 10 regions, 12 enemies, 6 bosses plus the Mother, and 5 endings. This file says where the build stands and how to carry on.

## Status at handoff

| Area | State |
|---|---|
| Godot 4.5 project, flow (title → regions → death → curtain → give or refuse a door → respawn), save, pause, HUD, post-FX, audio | **Done**, working |
| Five-door system (eye/ear/mouth/nose/skin effects, Mother's hold, untying knots, refusal penalty) | **Done** in code (`src/autoload/game.gd`, `src/core/*`) |
| Procedural score + SFX + voices | **Done** (`tools/gen_audio.py` → `assets/audio`) |
| AAA art pipeline (Flux paintings, Poly Haven PBR, Rodin 3D, Uthana rig + text-to-motion, Blender retarget) | **Done** (`tools/art`, `tools/blender`) |
| 3D cast: 18 rigged characters with 34 mocap clips, plus static creatures and props | **Done** (`assets/chars/*.glb`) |
| I · Dry Ghat (prologue) | **Rebuilt with the new art** (screens in `docs/screens/`). Needs polish (see below) |
| II · Ghatiya hub | Playable, but still **old primitive art** (watchmen, Kaki's words, knockers, Thirsty, scripted first death at the Mouth) |
| III–X regions, bosses, endings | **Not built.** `main.gd` shows "not yet built" for missing region scripts. `src/core/endings.gd` is a stub |
| Enemies (`src/enemies/*.gd`) | Logic written for all 12 + watchmen, but they still build **old `Fig.*` primitive puppets**. Swap to `CharModel.make("<name>")` |

## Run and test

- Open in Godot 4.5+ and press F5. The first import takes a while (~300 MB of assets).
- Headless screenshots (Xvfb + lavapipe; `tools/shot.sh` runs the import first):
  `SHOT_DIR=/tmp/s tools/shot.sh name --region=0 --at=14,8 --shots=160 --quit_after=162`
  Flags: `--region=N`, `--at=x,y` (teleport), `--doors=eye,ear`, `--auto_x=1` (hold right), `--god`, `--ending=x`, `--curtain`.
- Cast line-up render: `godot --path . res://test/lineup.tscn -- --anim=walk` (writes to a hardcoded scratch path; edit it).
- New `class_name` scripts need `godot --headless --import --path .` before they resolve.

## Environment setup for a new session

- Godot 4.5.1: `https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_linux.x86_64.zip`, symlinked to `/usr/local/bin/godot`.
- Software rendering: `apt-get install -y mesa-vulkan-drivers xvfb ffmpeg imagemagick espeak-ng`
- Blender 4.2: `https://download.blender.org/release/Blender4.2/blender-4.2.9-linux-x64.tar.xz` → `/opt/blender/blender-4.2.9-linux-x64/blender` (path is hardcoded in `tools/art/characters.py`).
- Python: `pip install numpy scipy pillow`
- Replicate token: `~/.config/dwaar/replicate_token` or `$REPLICATE_API_TOKEN`. **Never commit it.** The account balance was very low at handoff; under $5 the API throttles to 6 req/min, which `rep.py` waits out.

## Art pipeline (how to make more)

- `tools/art/rep.py`: `image()` (Flux 1.1 pro / ultra; ultra outputs get letterbox bars auto-cropped), `cutout()` (BiRefNet), `edit()` (Kontext; it refuses images of children), `model3d()`, `run()`. Everything is cached; prompts go to `tools/art/manifest.json`.
- `tools/art/sets.py` + `gen_slice.py <set>`: painted backdrops and cut-out props per region. Pattern: `ISO` suffix for isolated props on white (then cut out), `ultra` + 21:9 for panoramas. **Crop panoramas** so the horizon sits at the bottom (see `far_town.png`); the 3D ground provides the foreground.
- `tools/art/characters.py concept|model|rig|bake [names]`: Flux concept (A-pose, white bg) → Rodin Gen-2 (`tapose`, PBR) → `tools/blender/decimate.py` (tri budget + real height) → `uthana/create-character-v1` (Mixamo bones) → `tools/blender/retarget.py` bakes clips from `tools/art/motions.py`.
- `motions.py`: 34 Uthana text-to-motion clips (fetched on the "Y Bot" body). Options: `loop` (auto loop-point search), `trim_peak` (window around peak bone motion, used for attacks/jumps), `inplace_z`, `start_s`.
- `tools/art/polyhaven.py`: CC0 textures (needs a User-Agent) → `assets/pbr/<id>/`, and models.

## Engine pieces to know

- `src/world/build.gd` (`B`):
  - `B.mat(kind)` maps to Poly Haven PBR via the `PBR` table (silt, ground, earth, brick, oldbrick, limewash, plaster, terracotta, soot, wetclay, pit, laterite, rock, sandstone, roof, linen, redmud…), triplanar.
  - `B.painting(parent, path, pos, height, {grade, keep_lights, mirror, far, flicker, desat, bottom_fade})` places a painted quad. `far: true` uses `paint_far.gdshader` (no engine fog). The paint shader night-grades but keeps warm painted lamps and windows glowing.
  - `B.model(parent, name, pos, scale, rot)` loads a static GLB from `assets/chars` or a Poly Haven model.
- `src/world/char_model.gd` (`CharModel` extends `Puppet`):
  - `CharModel.make(name, {stepped, step_fps, scale})` gives the same `anim(state, speed, sub)` API as the old Puppet. States map to clips in `STATE_CLIP`.
  - `parts` are counter-scaled bone sockets (`r_fore` = right hand, `l_fore`, `head`, `chest`, `hips`, feet), and feet are grounded automatically.
  - `stepped = true` gives stop-motion playback, which the bible requires for everything made of clay.
- `src/core/player.gd` uses `CharModel.make("tesu")`. Props (paddle, lamp, indigo door patches) attach to sockets. **Check the socket offsets and rotations visually**; the patch positions on the head bone are guesses.

## Next steps, in order

1. **Polish Dry Ghat** (done: darker houses, dimmer lamps on the near villagers, boats at 1.6–1.8 scale; still needs a visual check) (`src/regions/r01_dry_ghat.gd`):
   - Painted houses still read too blue/white. Lower the `grade`, or regenerate them as night paintings.
   - The near villagers are over-lit by lamps.
   - The boat model is scaled too big (`B.model(boat,"boat",…,3.0)`); try about 1.6.
   - The moon in the far panorama is large.
   - Then play the giving cutscene end to end with `--auto_x=1` and check every beat.
2. **Swap enemy visuals to `CharModel`** (watchman, thirsty, kachcha, gaanth, pothead done, see `docs/screens/enemies_3d.jpg` and `pothead_3d.jpg`; all fall back to `Fig` if the GLB is missing; not yet seen on screen):
   - watchman → `"watchman"`, thirsty → `"thirsty"` (crawl clip), kachcha → `"kachcha"` (stepped), pot_head → `"pothead"` (stepped), stoker → `"stoker"` (carry clip), gaanth → `"gaanth"` (stepped).
   - glazed_double's copy → `CharModel.make("tesu")` with the glaze material; clay_copy → tesu with a clay material, stepped.
   - clay_bull → `B.model("bull")` with stop-motion transforms; silt_swimmer → `B.model("swimmer")`.
   - Remove the `Fig` usage. `Enemy.setup()` sets `puppet`, and the base class handles the rest.
3. **Rebuild II Ghatiya** with painted lanes (generate a `ghatiya` set: lane houses, kilns, door-niches, Kaki's house, the burning ground) and the 3D cast (Kaki `sit_talk`, Baba `sit`, villagers `band`).
4. **Build III–X** following the bible's region table, plus a painted set per region (the Drowned Ghats, Clay Pits with `pit`/`excavated_soil_wall`, the Hall of terracotta figures using `terracotta_child`/`hand`/`house`/`bull` models, the Knot House with the `cords` shader, the Kiln, the Wheel).
5. **Bosses** (models exist): Well-Ring Worm (stack `well_ring`), Buried Gang (`buried_gang`), the First (`first`, scaled ×8, moves only when unwatched via `Game.is_watched`), Knot-Keeper, Fire-Tender, Gaara, and the Veiled Mother (fought by facing away; she's reflected in `glazed_pot`s).
6. **Endings** in `src/core/endings.gd`: Raakh, Aadha Ghar, Aava, Ghunghat, Barsaat. Logic notes are in the bible and in `main.gd` (`play_ending`, `credits`).
7. Remove the old primitive `Fig` builders once nothing uses them, then do a full-playthrough test pass.

## Gotchas

- GDScript is strict about `:=` on Variant values (`max`, `clamp`, `abs`, dict lookups). Use explicit types or `maxf`/`clampf`.
- Godot's glTF import turns `mixamorig:Hips` into `mixamorig_Hips`, and armatures arrive at 0.01 scale (handled by sockets).
- The shell tool has a ~10 min foreground limit. Run long Replicate or Blender jobs with `nohup … &` and log to a file.
- Repo size is ~350 MB of binary assets. Keep characters at 30–50k tris with JPEG textures.
