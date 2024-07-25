#!/bin/bash

set_ai_env() {
    local default_file="$HOME/dev/ai_providers.env"
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
        echo "Error: $env_file not found"
        echo "Usage:"
        echo "  set-ai-env                  # Use $default_file"
        echo "  set-ai-env .                # Use ./$current_dir_default"
        echo "  set-ai-env .env             # Use ./.env"
        echo "  set-ai-env custom.env       # Use ./custom.env"
        echo "  set-ai-env /path/to/file.env # Use specified file"
        return 1
    fi

    echo "Using environment file: $env_file"

    # Read and export variables from the file
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        if [[ -z "$line" ]] || [[ "$line" =~ ^# ]]; then
            continue
        fi
        
        # Export the variable
        export "$line"
        echo "Exported: $line"
    done < "$env_file"

    echo "AI services environment variables have been set"
}

# Check if the script is being sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Script is being sourced, so we just need to execute the function
    set_ai_env "$@"
else
    # Script is being executed, not sourced
    # So we need to print the export commands for the caller to evaluate
    echo "# Run this command to set the environment variables:"
    echo "eval \"\$(\"$0\" \"$@\")\""
    set_ai_env "$@" | sed 's/^Exported: /export /'
fi
