#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/opt/node@24/bin:$PATH"
source scripts/avtools.sh
mkdir -p build out assets
node scripts/captions.mjs
if [ ! -s assets/score.wav ] || [ src/edit.json -nt assets/score.wav ] || [ scripts/score.mjs -nt assets/score.wav ]; then
    node scripts/score.mjs
fi
swiftc -O -module-cache-path build/swift-cache src/*.swift -o build/film
work="$(mktemp -d build/cut.XXXXXX)"
build/film render "$work/picture.mp4"
ff -hide_banner -loglevel error -i "$work/picture.mp4" -i assets/score.wav -map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -ar 48000 -ac 2 -b:a 224k -af volume=-1.5dB -map_metadata -1 -metadata title="AVIS3 Arena Plus · 三份隔振答卷" -metadata comment="Evaluation-1108 | 2026-11-18" -movflags +faststart "$work/final.mp4"
mv "$work/final.mp4" out/AVIS3-Plus-1118.mp4
rm "$work/picture.mp4"
rmdir "$work"
probe -v error -show_entries stream=codec_name,width,height,channels,sample_rate,r_frame_rate,nb_frames -show_entries format=duration,size -of json out/AVIS3-Plus-1118.mp4
