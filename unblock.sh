#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $0 <link>"
    exit 1
fi

# JSON configuration
read -r -d '' CONFIG << EOM
{
    "services": [
        {
            "name": "Google",
            "url": "https://webcache.googleusercontent.com/search?q=cache:",
            "error": "This page appears to have been removed"
        },
        {
            "name": "Freedium",
            "url": "https://freedium.cfd/",
            "error": "Please check the URL for any typing errors."
        },
        {
            "name": "Archive",
            "url": "https://web.archive.org/web/",
            "error": "Wayback Machine doesn't have that page archived"
        },
        {
            "name": "Ghostarchive",
            "url": "https://ghostarchive.org/search?term=",
            "error": "No archives for that site."
        }
    ]
}
EOM

check_url() {
    local url="$1"
    local service="$2"
    local error_msg="$3"
    local response
    local http_code
    local body

    response=$(curl -sL -w "HTTPSTATUS:%{http_code}" -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36" "$url")
    http_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    body=$(echo "$response" | sed -e 's/HTTPSTATUS\:.*//g')

    echo "Response code: $http_code"

    if [ "$http_code" = "200" ]; then
        if echo "$body" | grep -q "$error_msg"; then
            echo "$service: Error found"
            return 1
        fi
        return 0
    else
        echo "$service returned non-200 status code"
        return 1
    fi
}

# Function to add www if not present
add_www() {
    local url="$1"
    if [[ "$url" =~ ^https?://www\. ]]; then
        echo "$url"
    elif [[ "$url" =~ ^https?:// ]]; then
        echo "${url//:\/\//://www.}"
    else
        echo "https://www.$url"
    fi
}

original_url="$1"
original_url=$(add_www "$original_url")
echo "Using URL: $original_url"

# Parse JSON and loop through services
echo "$CONFIG" | jq -c '.services[]' | while read -r service; do
    name=$(echo "$service" | jq -r '.name')
    url=$(echo "$service" | jq -r '.url')
    error=$(echo "$service" | jq -r '.error')
    
    cache_url="${url}${original_url}"
    echo "Checking $name..."
    if check_url "$cache_url" "$name" "$error"; then
        echo "$name version available: $cache_url"
        exit 0
    else
        echo "$name version not available or blocked."
        echo
    fi
done

# Check if any service succeeded
if [ $? -ne 0 ]; then
    echo "No cached or unblocked version found."
    exit 1
fi