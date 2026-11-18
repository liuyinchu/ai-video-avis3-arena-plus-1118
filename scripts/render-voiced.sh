#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/opt/node@24/bin:$PATH"
source scripts/avtools.sh
export AVTOOLS_DIR="$AVBIN"
mkdir -p build/voiced out assets
if [ ! -s assets/score.wav ]; then node scripts/score.mjs; fi
work="$(mktemp -d build/voice-render.XXXXXX)"
node scripts/assemble-voice.mjs "$work"
swiftc -O -module-cache-path build/swift-cache src/*.swift -o "$work/film"
AVIS_FILM_EDIT="$work/edit.json" "$work/film" render "$work/picture.mp4"
ff -loglevel error -i "$work/picture.mp4" -i "$work/mix.wav" -map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -ar 48000 -ac 2 -b:a 224k -metadata:s:a:0 language=zho -metadata:s:a:0 title="普通话旁白与配乐" -metadata title="AVIS3 Arena Plus · 三份隔振答卷 · 中文配音版" -metadata comment="Breeze TTS 2 · Evaluation-1108" -movflags +faststart "$work/final.mp4"
name=out/AVIS3-Plus-1118-Breeze
mv "$work/final.mp4" "$name.mp4"
mv "$work/captions.srt" "$name.zh-Hans.srt"
mv "$work/voice.wav" "$name-voice.wav"
mv "$work/edit.json" "$work/placement.json" "$work/mix.wav" build/voiced/
rm -r "$work"
