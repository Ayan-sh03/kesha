# Dwaar · द्वार

*Five doors. One veil. A village that gave away a girl.*

A 2.5D dark action-platformer in Godot 4.5, built from the *Dwaar* concept bible (v0.2).

> **Status: early work in progress.** Playable: **I · Dry Ghat** (prologue) and **II · Ghatiya** (the hub, with Kaki's three words). The rest of the descent is not built yet. The current visuals are placeholder primitives and are being replaced.

## Run

1. Install [Godot 4.5+](https://godotengine.org/download) (standard build, not .NET).
2. Open `project.godot` in the editor (the first import takes a minute), then press **F5**.

## Controls

| Key | Action | Key | Action |
|---|---|---|---|
| A / D | run | S | creep quietly |
| Space | jump | W / S | climb rings, ropes, rough walls |
| Left mouse / J | paddle (3-hit combo) | Right mouse / K | aim sling, release to loose |
| Q | block (parry on time) | Shift | roll |
| E | set a lamp: checkpoint + watcher | F | interact |
| 1 2 3 | Shut · Open · Break | H | close your doors (ears, breath, eyes) |
| R | pour water for the Thirsty | Esc | pause |

Gamepad is supported too.

## What's in it

- **The five doors.** Every death takes Tesu to the Veiled Mother's curtain, where he gives a door (eye, ear, mouth, nose or skin), or refuses. Each door changes play. Eye: the left third of the screen goes dark, and Bindu draws chalk marks. Ear: the score goes dull, and sounds draw as rings. Mouth: the words become handprints Bindu speaks for him. Nose: smoke can't hurt him. Skin: double health and no HUD.
- The curtain is the progress bar: wind, a face pressing through, a handprint, a gap, and a burning hem.
- Clay only moves when nobody is looking: on screen, faced, not on the blind side, or watched by a set lamp.
- All 12 bestiary creatures and the watchmen exist as scripts (`src/enemies/`).

## Assets

Everything is generated, so there are no third-party art or audio files:

- `tools/gen_audio.py`: the score (Ghatiya, The Veil, Dead River, The Kiln, Raakh, plus variations) from synthesized clay-pot drums, ghungroo, ektara, a clay whistle and a tanpura drone; all SFX; voices via espeak-ng.
- `tools/gen_textures.py`: tileable textures and Bindu's chalk marks.
- Fonts: Cormorant Garamond, Tiro Devanagari Hindi, Kalam (SIL OFL, `assets/fonts/`).

## Testing

`tools/shot.sh <name> --region=N --shots=60,300 --quit_after=310` renders a region headlessly (Xvfb + lavapipe) and saves screenshots. Extra flags: `--doors=eye,ear`, `--auto_x=1`, `--god`.

Ghatiya's faith, gods and rites are invented. The giving of a child is the story's horror: a wrong the village chooses, never anyone's real tradition.
