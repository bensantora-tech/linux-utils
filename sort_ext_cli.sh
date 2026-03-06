#!/usr/bin/env bash
# vim: ft=sh

# Recursive File Extension Sorter - Safe version
# Copies files into sorted_files/ subfolders by extension (lowercase)
# Skips hidden files (.*)
# Does NOT overwrite existing files in destination (-n)
# Handles all filenames correctly (newlines, special chars, spaces)

set -euo pipefail

SOURCE_DIR="${1:-$(pwd)}"
SORTED_DIR="$SOURCE_DIR/sorted_files"

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: '$SOURCE_DIR' is not a directory" >&2
    exit 1
fi

mkdir -p "$SORTED_DIR" || {
    echo "Cannot create output directory $SORTED_DIR" >&2
    exit 1
}

declare -A ext_count
total_scanned=0
total_copied=0

echo "Scanning ${SOURCE_DIR} … (may be slow on very large directories)"
echo "→ Hidden files (starting with .) are being skipped"
echo "→ Files already in $SORTED_DIR are skipped"
echo "→ Existing files in target folders are NOT overwritten"
echo ""

while IFS= read -r -d '' file; do
    # Skip anything already inside our output directory
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

    # -n = do not overwrite existing file
    # -p = preserve timestamps/attributes
    if cp -pn "$file" "$target"; then
        ((total_copied++))
        ((ext_count[$ext]++))
    fi

    ((total_scanned++))

    # Progress feedback
    (( total_scanned % 500 == 0 )) && \
        printf "… scanned %d files (%d copied so far)\n" "$total_scanned" "$total_copied"

done < <(find "$SOURCE_DIR" -type f -not -path '*/\.*' -not -path "$SORTED_DIR*" -print0)

echo
echo "Finished."
echo "Scanned: $total_scanned files"
echo "Copied : $total_copied files  (skipped if already existed)"

if (( total_copied > 0 )); then
    echo
    echo "Files organized by extension:"
    for e in $(printf '%s\n' "${!ext_count[@]}" | sort --ignore-case); do
        printf '  %-16s : %5d\n' "$e" "${ext_count[$e]}"
    done
fi

echo
echo "All organized files are in:"
echo "  $SORTED_DIR"
echo
echo "Original files were not modified or deleted."
