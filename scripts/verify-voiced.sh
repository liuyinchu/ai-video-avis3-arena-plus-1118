#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/opt/node@24/bin:$PATH"
source scripts/avtools.sh
name=out/AVIS3-Plus-1118-Breeze
qa=build/voiced/review
mkdir -p "$qa"
probe -v error -count_frames -show_entries stream=codec_type,codec_name,width,height,pix_fmt,avg_frame_rate,start_time,duration,nb_frames,nb_read_frames,sample_rate,channels:stream_tags=language -show_entries format=duration,size -of json "$name.mp4" > "$qa/streams.json" 2>"$qa/read-errors.log"
ff -v error -xerror -i "$name.mp4" -map 0:v:0 -map 0:a:0 -vf scale=320:180 -c:v mjpeg -q:v 10 -c:a pcm_s16le -f null - 2>"$qa/decode.log"
ff -hide_banner -nostats -i "$name.mp4" -vn -af loudnorm=I=-16.5:TP=-1.5:LRA=10:print_format=json -f null - >"$qa/loudness.log" 2>&1
ff -v error -y -i "$name.mp4" -vn -ar 48000 -ac 2 -c:a pcm_s16le "$qa/decoded.wav"
node scripts/check-voiced.mjs
rm "$qa/decoded.wav"
