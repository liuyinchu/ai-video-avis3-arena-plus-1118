#!/bin/bash
# Source this file after changing to the project root.
if [ -n "${AVTOOLS_DIR:-}" ]; then
    AVBIN="$AVTOOLS_DIR"
elif command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null; then
    AVBIN="$(dirname "$(command -v ffmpeg)")"
else
    AVBIN="$(cd ../ai-video-1108-opus/video/node_modules/@remotion/compositor-darwin-arm64 && pwd -P)"
fi
ff() { DYLD_LIBRARY_PATH="$AVBIN${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" "$AVBIN/ffmpeg" -nostdin "$@"; }
probe() { DYLD_LIBRARY_PATH="$AVBIN${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" "$AVBIN/ffprobe" "$@"; }
