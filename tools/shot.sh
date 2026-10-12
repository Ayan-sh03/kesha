#!/bin/bash
# Render the game under a virtual display and save screenshots.
# usage: tools/shot.sh <name> <user-args...>   e.g. tools/shot.sh r1 --region=0 --shots=60,200 --quit_after=210
OUT=${SHOT_DIR:-/tmp/dwaar_shots}
mkdir -p "$OUT"
NAME=$1; shift
cd "$(dirname "$0")/.."
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json timeout ${TIMEOUT:-300} xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --resolution ${RES:-1280x720} -- --autotest --shot="$OUT/$NAME" "$@" 2>&1 | grep -vE "ALSA|alsa|audio_driver|dummy driver|^\s*at: (init|initialize)" 
