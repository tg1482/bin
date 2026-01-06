#!/bin/bash

# Organize screenshots from Desktop into Desktop/screenshots/YYYY-MM/

DESKTOP="$HOME/Desktop"
SCREENSHOTS_DIR="$DESKTOP/screenshots"

# Ensure screenshots directory exists
mkdir -p "$SCREENSHOTS_DIR"

# Count for reporting
moved=0
skipped=0

# Find screenshot files matching the pattern
for file in "$DESKTOP"/Screenshot\ *.png "$DESKTOP"/Screenshot\ *.jpg; do
    [ -e "$file" ] || continue
    
    filename=$(basename "$file")
    
    # Extract date from filename: "Screenshot 2025-12-23 at 8.50.28 AM.png"
    if [[ "$filename" =~ Screenshot\ ([0-9]{4})-([0-9]{2})-([0-9]{2}) ]]; then
        year="${BASH_REMATCH[1]}"
        month="${BASH_REMATCH[2]}"
        
        dest_dir="$SCREENSHOTS_DIR/$year-$month"
        mkdir -p "$dest_dir"
        
        mv "$file" "$dest_dir/"
        echo "Moved: $filename -> $year-$month/"
        ((moved++))
    else
        echo "Skipped (no date match): $filename"
        ((skipped++))
    fi
done

echo
echo "Done: $moved moved, $skipped skipped"

