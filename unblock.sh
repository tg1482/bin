#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: unblock <link>"
    exit 1
fi

url="https://webcache.googleusercontent.com/search?q=cache:$1"

# Use curl to fetch the content and check for 404 error message
response=$(curl -s "$url")
if echo "$response" | grep -q "Error 404 (Not Found)"; then
    echo "Cached version not found."
else
    echo "$url"
fi