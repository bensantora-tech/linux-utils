#!/bin/bash

# === Check Dependencies ===
for cmd in ffmpeg ffprobe yad; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ $cmd not found"
        [ "$cmd" = "yad" ]    && echo "Install: sudo apt install yad"
        [ "$cmd" = "ffmpeg" ] && echo "Install: sudo apt install ffmpeg"
        [ "$cmd" = "ffprobe" ] && echo "Install: sudo apt install ffmpeg"
        exit 1
    fi
done

# === 1. Select Input PNG ===
png_file=$(yad --file \
    --title="<b>📁 Select PNG Image</b>" \
    --file-filter="PNG Images | *.png" \
    --filename="$HOME/Pictures/" \
    --width=700 \
    --height=500 \
    --button=cancel \
    --button="ok:0")

[ -z "$png_file" ] && yad --error --text="<span font='18'>🛑 No PNG selected.</span>" --width=400 && exit 1
[ ! -f "$png_file" ] && yad --error --text="<span font='18'>❌ PNG file not found:\n$png_file</span>" --width=500 && exit 1

# === 2. Select MP3 Audio File ===
mp3_file=$(yad --file \
    --title="<b>🎵 Select MP3 Audio</b>" \
    --file-filter="MP3 Audio | *.mp3" \
    --filename="$HOME/Music/" \
    --width=700 \
    --height=500 \
    --button=cancel \
    --button="ok:0")

[ -z "$mp3_file" ] && yad --error --text="<span font='18'>🛑 No MP3 selected.</span>" --width=400 && exit 1
[ ! -f "$mp3_file" ] && yad --error --text="<span font='18'>❌ MP3 file not found:\n$mp3_file</span>" --width=500 && exit 1

# === 3. Get Video Duration (same as audio) ===
duration=$(ffprobe -i "$mp3_file" -show_entries format=duration -v quiet -of csv="p=0")
duration=${duration%.*}  # Remove decimal part

# === 4. Set Output Path ===
mkdir -p "$HOME/Videos"
default_output="$HOME/Videos/$(date +"%Y%m%d_%H%M%S")_output.mp4"

output_path=$(yad --file \
    --title="<b>💾 Save Output Video As</b>" \
    --filename="$default_output" \
    --save \
    --confirm-overwrite \
    --file-filter="MP4 Video | *.mp4" \
    --width=700 \
    --height=500 \
    --button=cancel \
    --button="ok:0")

[ -z "$output_path" ] && yad --error --text="<span font='18'>🛑 No output path selected.</span>" --width=400 && exit 1

# Ensure .mp4 extension
case "$output_path" in
    *.mp4) ;;
    *) output_path="$output_path.mp4" ;;
esac

# === 5. Confirm ===
if ! yad --question \
    --title="<b>🔄 Confirm Video Creation</b>" \
    --text="<span font='16'>
    <b>Create video from:</b>

    <b>Image:</b>    $png_file
    <b>Audio:</b>    $mp3_file
    <b>Duration:</b> $duration seconds

    <b>Output:</b>   $output_path
    </span>" \
    --width=600 --height=300; then
    yad --info --text="<span font='18'>↩️ Cancelled.</span>" --width=400
    exit 0
fi

# === 6. Process with progress dialog ===
ffmpeg \
    -loop 1 -framerate 2 -i "$png_file" \
    -i "$mp3_file" \
    -c:v libx264 -tune stillimage -pix_fmt yuv420p -vf "scale=iw-mod(iw\,2):ih-mod(ih\,2)" -preset veryslow \
    -c:a aac -b:a 192k \
    -shortest -y "$output_path" > /tmp/ffmpeg-yad.log 2>&1 &

FFMPEG_PID=$!

yad --progress --pulsate --auto-close --no-buttons \
    --text="<span font='16'>⚙️ Processing... This may take a while.</span>" \
    --width=400 &

YAD_PID=$!
wait "$FFMPEG_PID"
FFMPEG_EXIT=$?
kill "$YAD_PID" 2>/dev/null

# === 7. Result ===
if [ "$FFMPEG_EXIT" -eq 0 ]; then
    yad --info \
        --text="<span font='18'>✅ Video Created Successfully!</span>
<span font='14'>Saved as:\n<b>$output_path</b></span>" \
        --width=500
else
    error_msg=$(tail -n15 /tmp/ffmpeg-yad.log | sed 's/^/  | /')
    yad --error \
        --text="<span font='18'>❌ FFmpeg Failed!</span>
<span font='12'>Error:\n$error_msg</span>" \
        --width=700 --height=400
    exit 1
fi
