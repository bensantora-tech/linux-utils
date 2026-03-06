#!/bin/bash
# Screen Recorder - YAD + FFmpeg (X11 only)

# Check dependencies
for cmd in ffmpeg yad xdpyinfo; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "❌ $cmd not found. Install it and try again."
        exit 1
    fi
done

FFMPEG_PID=""
OUTPUT_FILE=""
RECORDING_FILE=""

OUT_DIR="$HOME/Videos/ScreenRecordings"
mkdir -p "$OUT_DIR"

# Get screen resolution (fallback to 1920x1080)
RESOLUTION=$(xdpyinfo | awk -F'[ x]+' '/dimensions:/ {print $3 "x" $4; exit}')
[ -z "$RESOLUTION" ] && RESOLUTION="1920x1080"

while true; do
    yad --title="Screen Recorder" \
        --text="Click START to begin recording.\nFiles saved to:\n$OUT_DIR" \
        --button="START:0" \
        --button="STOP:1" \
        --button="Quit:2" \
        --timeout=60 --timeout-indicator=bottom \
        --borders=20 --width=400

    case $? in
        0)  # START
            if [ -n "$FFMPEG_PID" ]; then
                yad --error --text="Already recording!" --timeout=3
                continue
            fi

            # Generate fresh filenames on each recording
            TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
            RECORDING_FILE="${XDG_RUNTIME_DIR:-/tmp}/scr-rec-${TIMESTAMP}.mp4"
            OUTPUT_FILE="$OUT_DIR/rec-${TIMESTAMP}.mp4"

            yad --notification \
                --text="Recording started..." \
                --image="media-record" \
                --timeout=2 &

            ffmpeg -f x11grab \
                -s "$RESOLUTION" \
                -i ":0.0" \
                -c:v libx264 \
                -preset ultrafast \
                -pix_fmt yuv420p \
                "$RECORDING_FILE" > /dev/null 2>&1 &

            FFMPEG_PID=$!
            ;;

        1)  # STOP
            if [ -n "$FFMPEG_PID" ] && kill -0 "$FFMPEG_PID" 2>/dev/null; then
                kill -SIGINT "$FFMPEG_PID"
                wait "$FFMPEG_PID" 2>/dev/null
                if [ -f "$RECORDING_FILE" ]; then
                    mv "$RECORDING_FILE" "$OUTPUT_FILE"
                    yad --info --text="Saved to:\n$OUTPUT_FILE"
                else
                    yad --error --text="Recording failed or file missing."
                fi
                FFMPEG_PID=""
                RECORDING_FILE=""
            else
                yad --error --text="Not currently recording." --timeout=3
            fi
            ;;

        2|252)  # QUIT or timeout
            if [ -n "$FFMPEG_PID" ]; then
                yad --question --text="Still recording! Stop and quit?" && \
                    kill -SIGINT "$FFMPEG_PID" 2>/dev/null
                wait "$FFMPEG_PID" 2>/dev/null
                if [ -f "$RECORDING_FILE" ]; then
                    mv "$RECORDING_FILE" "$OUTPUT_FILE"
                    yad --info --text="Saved last recording to:\n$OUTPUT_FILE"
                fi
            fi
            exit 0
            ;;
    esac
done
