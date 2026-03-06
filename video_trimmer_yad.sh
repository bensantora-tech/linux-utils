#!/bin/bash
# FFmpeg Video Trimmer - YAD GUI
# Requires: ffmpeg, ffprobe, yad, bc

for cmd in ffmpeg ffprobe yad bc; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "❌ $cmd not found. Install it and try again."
        exit 1
    fi
done

convert_to_seconds() {
    local time_str="$1"
    # Plain number — already seconds
    if [[ "$time_str" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "$time_str"
        return
    fi
    local hours=0 minutes=0 seconds=0
    IFS=':' read -ra parts <<< "$time_str"
    case ${#parts[@]} in
        2) minutes="${parts[0]}"; seconds="${parts[1]}" ;;
        3) hours="${parts[0]}"; minutes="${parts[1]}"; seconds="${parts[2]}" ;;
        *) echo "Invalid time format: $time_str" >&2; return 1 ;;
    esac
    echo "$(bc <<< "$hours*3600 + $minutes*60 + $seconds")"
}

# Step 1: Select input file
input_file=$(yad --file-selection --title="Step 1: Select Input Video" \
    --file-filter="Video Files | *.mp4 *.mkv *.avi *.mov" \
    --center)
[ -z "$input_file" ] && exit 0
[ ! -f "$input_file" ] && yad --error --text="File not found: $input_file" --center && exit 1

# Get video duration
duration_raw=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$input_file")
duration_int=${duration_raw%.*}
duration_fmt=$(date -u -d "@$duration_int" +%T)

# Suggest output filename
base="${input_file%.*}"
ext="${input_file##*.}"
suggested_output="${base}_trimmed.${ext}"

# Step 2: Get trim parameters
while true; do
    FORM=$(yad --form --title="Step 2: Set Trim Parameters" --width=550 --center \
        --text="Video length: <b>$duration_fmt</b>  |  Times accept HH:MM:SS or seconds" \
        --field="Input File":RO "$input_file" \
        --field="Output File":SFL "$suggested_output" \
        --field="Start Time (e.g. 0:30 or 30)": "0" \
        --field="End Time (e.g. 1:45 or 105)": "" \
        --button="Cancel:1" \
        --button="Next:0")
    [ $? -ne 0 ] && exit 0

    output_file=$(echo "$FORM" | cut -d'|' -f2)
    start_time=$(echo "$FORM"  | cut -d'|' -f3)
    end_time=$(echo "$FORM"    | cut -d'|' -f4)

    [ -z "$output_file" ] && yad --error --text="Please specify an output file." --center && continue
    [ -z "$end_time" ]    && yad --error --text="Please specify an end time." --center && continue

    start_sec=$(convert_to_seconds "$start_time") || { yad --error --text="Invalid start time format." --center; continue; }
    end_sec=$(convert_to_seconds "$end_time")     || { yad --error --text="Invalid end time format." --center; continue; }

    if (( $(echo "$start_sec >= $end_sec" | bc -l) )); then
        yad --error --text="Start time must be earlier than end time." --center
        continue
    fi

    break
done

# Confirm
yad --question \
    --text="Trim <b>$(basename "$input_file")</b>\nFrom: <b>$start_time</b>  To: <b>$end_time</b>\n\nOutput: $output_file" \
    --center --button="Cancel:1" --button="Proceed:0"
[ $? -ne 0 ] && exit 0

# Trim — -ss before -i for fast seeking, PIPESTATUS to get ffmpeg exit code
ffmpeg -ss "$start_sec" -to "$end_sec" \
    -i "$input_file" \
    -c:v libx264 -crf 22 -preset fast \
    -c:a aac -movflags +faststart \
    -y "$output_file" 2>&1 | \
    yad --progress --pulsate --auto-close \
        --text="Trimming video..." --center

if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    yad --info --text="✅ Trimmed successfully!\n\nSaved as:\n$output_file" --center
else
    yad --error --text="❌ FFmpeg failed. Check that the output path is valid." --center
fi
