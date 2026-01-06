#!/bin/bash

# blink - Convert URLs with query parameters to Slack-friendly links
# Usage: blink -r <url>

show_usage() {
    echo "Usage: $(basename "$0") [-f format] <url>"
    echo "       echo <url> | $(basename "$0") [-f format]"
    echo ""
    echo "Options:"
    echo "  -f format   Output format: md (default), slack, simple"
    echo ""
    echo "Extracts the first numeric value from URL query parameters"
    echo "Always copies to clipboard and prints to stdout"
    exit 1
}

# Parse arguments
format="md"
while getopts "f:" opt; do
    case $opt in
        f)
            format="$OPTARG"
            ;;
        *)
            show_usage
            ;;
    esac
done

shift $((OPTIND-1))

# Get URL from argument or stdin
if [ -n "$1" ]; then
    url="$1"
elif [ ! -t 0 ]; then
    # Read from stdin if not a terminal (i.e., piped input)
    read -r url
else
    show_usage
fi

if [ -z "$url" ]; then
    show_usage
fi

# Extract the first non-empty numeric value from query parameters
# Parse query string and find first number
if [[ "$url" =~ \?([^#]*) ]]; then
    query_string="${BASH_REMATCH[1]}"
    
    # Split by & and find first non-empty value that's a number
    IFS='&' read -ra params <<< "$query_string"
    for param in "${params[@]}"; do
        if [[ "$param" =~ =([0-9]+)$ ]]; then
            number="${BASH_REMATCH[1]}"
            break
        fi
    done
fi

if [ -z "$number" ]; then
    echo "Error: No numeric value found in URL query parameters" >&2
    exit 1
fi

# Generate output based on format
case "$format" in
    slack)
        output="<$url|$number>"
        ;;
    md)
        output="[$number]($url)"
        ;;
    simple)
        output="$number - $url"
        ;;
    *)
        echo "Unknown format: $format" >&2
        exit 1
        ;;
esac

# Output and copy to clipboard
echo "$output"
echo "$output" | pbcopy

