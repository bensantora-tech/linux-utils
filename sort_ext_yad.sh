#!/bin/bash

# Recursive File Extension Sorter - YAD GUI version
# Copies files into sorted_files/ subfolders by extension (lowercase)
# Skips hidden files (.*)
# Does NOT overwrite existing files in destination
# Handles all filenames correctly (spaces, special chars)

SOURCE_DIR="${1:-$(pwd)}"
SORTED_DIR="$SOURCE_DIR/sorted_files"

if [[ ! -d "$SOURCE_DIR" ]]; then
    yad --error --text="Error: '$SOURCE_DIR' is not a directory." --width=400
    exit 1
fi

mkdir -p "$SORTED_DIR" || {
    yad --error --text="Cannot create output directory:\n$SORTED_DIR" --width=500
    exit 1
}

declare -A ext_count
total_copied=0
total_skipped=0

while IFS= read -r -d '' file; do
    [[ $file == "$SORTED_DIR"* ]] && continue

    filename=$(basename "$file")

    if [[ $filename == *.* ]]; then
        ext="${filename##*.}"
        ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
    else
        ext="no_extension"
    fi

    target_dir="$SORTED_DIR/$ext"
    mkdir -p "$target_dir" || continue

    target="$target_dir/$filename"

    if [[ -f "$target" ]]; then
        ((total_skipped++))
        continue
    fi

    if cp -p "$file" "$target"; then
        ((total_copied++))
        ((ext_count[$ext]++))
    fi

done < <(find "$SOURCE_DIR" -type f -not -path '*/\.*' -not -path "$SORTED_DIR*" -print0)

# Build summary
summary="Finished sorting files in:\n$SOURCE_DIR\n\nCopied:  $total_copied files\nSkipped: $total_skipped files (already existed)\n\nOriginal files were not modified.\n\nFiles by extension:"

for e in $(printf '%s\n' "${!ext_count[@]}" | sort --ignore-case); do
    summary="$summary\n  $e : ${ext_count[$e]}"
done

yad --info \
    --title="Sort Complete" \
    --text="$summary" \
    --width=500 \
    --height=400 \
    --button="OK:0"
