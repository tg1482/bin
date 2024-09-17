#!/bin/bash

set_ai_env() {
    local default_file="$HOME/dev/bin/ai_providers.env"
    local current_dir_default="ai_providers.env"
    local env_file=""
    case "$1" in
        "")
            env_file="$default_file"
            ;;
        ".")
            env_file="./$current_dir_default"
            ;;
        */*)
            # If the argument contains a slash, treat it as a path
            env_file="$1"
            ;;
        *)
            # Otherwise, treat it as a filename in the current directory
            env_file="./$1"
            ;;
    esac
    # Check if the file exists
    if [ ! -f "$env_file" ]; then
        echo "Error: $env_file not found" >&2
        echo "Usage:" >&2
        echo "  set-ai-env                  # Use $default_file" >&2
        echo "  set-ai-env .                # Use ./$current_dir_default" >&2
        echo "  set-ai-env .env             # Use ./.env" >&2
        echo "  set-ai-env custom.env       # Use ./custom.env" >&2
        echo "  set-ai-env /path/to/file.env # Use specified file" >&2
        return 1
    fi
    [ "$1" != "get" ] && echo "Using environment file: $env_file"
    # Read and export variables from the file
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        if [[ -z "$line" ]] || [[ "$line" =~ ^# ]]; then
            continue
        fi
        
        # Export the variable
        export "$line"
        [ "$1" != "get" ] && echo "Exported: $line"
    done < "$env_file"
    [ "$1" != "get" ] && echo "AI services environment variables have been set"
}

get_secret() {
    local key="$1"
    local value="${!key}"
    
    if [ -n "$value" ]; then
        echo "$value"
    else
        echo "Error: $key not found in environment variables" >&2
        return 1
    fi
}

# Main script logic
if [ "$1" = "get" ]; then
    if [ -z "$2" ]; then
        echo "Error: Please specify a key to retrieve" >&2
        echo "Usage: $0 get KEY_NAME" >&2
        exit 1
    fi
    
    # First, set the environment variables quietly
    set_ai_env > /dev/null 2>&1
    
    # Then, get the requested secret
    get_secret "$2"
elif [ "$1" = "set-env" ]; then
    shift
    set_ai_env "$@"
else
    echo "Error: Unknown command" >&2
    echo "Usage: $0 get KEY_NAME" >&2
    echo "       $0 set-env [ENV_FILE]" >&2
    exit 1
fi

# Check if the script is being sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Script is being sourced, so we just need to execute the function
    :
else
    # Script is being executed, not sourced
    # So we need to print the export commands for the caller to evaluate
    if [ "$1" = "set-env" ]; then
        echo "# Run this command to set the environment variables:"
        echo "eval \"\$(\"$0\" \"$@\")\""
        set_ai_env "$@" | sed 's/^Exported: /export /'
    fi
fi
