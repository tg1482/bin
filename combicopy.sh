#!/bin/bash

add_line_numbers=false

# Check for -l option
while getopts "l" opt; do
  case $opt in
    l)
      add_line_numbers=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Combine all files in the current directory
for file in *; do
    if [ -f "$file" ]; then
        echo "// $file" >> combined_output.txt
        if $add_line_numbers; then
            nl -ba "$file" >> combined_output.txt
        else
            cat "$file" >> combined_output.txt
        fi
        echo -e "\n" >> combined_output.txt
    fi
done

# Copy the combined content to clipboard
# This uses xclip for Linux systems. For macOS, replace with pbcopy
if command -v xclip &> /dev/null; then
    cat combined_output.txt | xclip -selection clipboard
    echo "Content copied to clipboard."
elif command -v pbcopy &> /dev/null; then
    cat combined_output.txt | pbcopy
    echo "Content copied to clipboard."
else
    echo "Unable to copy to clipboard. Please install xclip (Linux) or use pbcopy (macOS)."
fi

# Clean up
rm combined_output.txt