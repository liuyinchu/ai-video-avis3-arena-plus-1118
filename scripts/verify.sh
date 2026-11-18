#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/opt/node@24/bin:$PATH"
source scripts/avtools.sh
movie=out/AVIS3-Plus-1118.mp4
qa=build/review
mkdir -p "$qa"
probe -v error -count_frames -show_entries stream=index,codec_name,width,height,pix_fmt,color_space,color_transfer,avg_frame_rate,nb_frames,nb_read_frames,sample_rate,channels,channel_layout,start_time,duration -show_entries format=duration,size -of json "$movie" > "$qa/streams.json"
ff -v error -xerror -i "$movie" -map 0:v:0 -map 0:a:0 -vf scale=320:180 -c:v mjpeg -q:v 10 -c:a pcm_s16le -f null - 2>"$qa/decode.log"
ff -hide_banner -nostats -i "$movie" -vn -af loudnorm=I=-16:TP=-1.5:LRA=10:print_format=json -f null - >"$qa/loudness.log" 2>&1
ff -hide_banner -nostats -i "$movie" -vn -af silencedetect=n=-55dB:d=0.6 -f null - >"$qa/silence.log" 2>&1
ff -v error -y -i "$movie" -vn -ar 44100 -ac 2 -c:a pcm_s16le -f wav "$qa/decoded-mix.wav"
node scripts/check-export.mjs
rm "$qa/decoded-mix.wav"
