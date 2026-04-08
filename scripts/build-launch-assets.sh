#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FRAMES_DIR="$PROJECT_DIR/.build/launch-assets/frames"
DEMO_DIR="$PROJECT_DIR/docs/assets/demo"
MANIFEST_PATH="$FRAMES_DIR/manifest.txt"
MP4_PATH="$DEMO_DIR/cleanmd-proof-demo.mp4"
GIF_PATH="$DEMO_DIR/cleanmd-proof-demo.gif"

mkdir -p "$FRAMES_DIR" "$DEMO_DIR"

swift "$PROJECT_DIR/scripts/build-launch-assets.swift" "$FRAMES_DIR"

cat >"$MANIFEST_PATH" <<EOF
file '$FRAMES_DIR/scene-1.png'
duration 4
file '$FRAMES_DIR/scene-2.png'
duration 4
file '$FRAMES_DIR/scene-3.png'
duration 4
file '$FRAMES_DIR/scene-4.png'
duration 4
file '$FRAMES_DIR/scene-5.png'
duration 4
file '$FRAMES_DIR/scene-6.png'
duration 4
file '$FRAMES_DIR/scene-6.png'
EOF

ffmpeg -y \
  -f concat \
  -safe 0 \
  -i "$MANIFEST_PATH" \
  -vf "fps=30,format=yuv420p" \
  -c:v libx264 \
  -pix_fmt yuv420p \
  "$MP4_PATH"

ffmpeg -y \
  -f concat \
  -safe 0 \
  -i "$MANIFEST_PATH" \
  -vf "fps=12,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=reserve_transparent=0[p];[s1][p]paletteuse" \
  "$GIF_PATH"

printf 'Generated launch assets:\n- %s\n- %s\n' "$MP4_PATH" "$GIF_PATH"
