#!/bin/bash

readonly DEFAULT_ENV_FILE="$HOME/dev/bin/ai_providers.env"
readonly CURRENT_DIR_DEFAULT="ai_providers.env"

resolve_env_file() {
    local selection="$1"
    case "$selection" in
        "")
            echo "$DEFAULT_ENV_FILE"
            ;;
        ".")
            echo "./$CURRENT_DIR_DEFAULT"
            ;;
        */*)
            echo "$selection"
            ;;
        *)
            echo "./$selection"
            ;;
    esac
}

print_env_file_usage() {
    local env_file="$1"
    echo "Error: $env_file not found" >&2
    echo "Usage:" >&2
    echo "  $0 set-env                  # Use $DEFAULT_ENV_FILE" >&2
    echo "  $0 set-env .                # Use ./$CURRENT_DIR_DEFAULT" >&2
    echo "  $0 set-env .env             # Use ./.env" >&2
    echo "  $0 set-env custom.env       # Use ./custom.env" >&2
    echo "  $0 set-env /path/to/file.env # Use specified file" >&2
    echo "  $0 list [ENV_FILE]          # List available keys in a file" >&2
    echo "  $0 -i [ENV_FILE]            # Interactive pick + print value" >&2
}

resolve_existing_env_file() {
    local env_file
    env_file="$(resolve_env_file "$1")"
    if [ ! -f "$env_file" ]; then
        print_env_file_usage "$env_file"
        return 1
    fi
    echo "$env_file"
}

print_usage() {
    echo "Usage:" >&2
    echo "  $0 get KEY_NAME" >&2
    echo "  $0 list [ENV_FILE]" >&2
    echo "  $0 set-env [ENV_FILE]" >&2
    echo "  $0 -i [ENV_FILE]            # Interactive pick + print value" >&2
}

set_ai_env() {
    local env_file
    env_file="$(resolve_existing_env_file "$1")" || return $?

    [ "$1" != "get" ] && echo "Using environment file: $env_file"
    # Read and export variables from the file
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments (including whitespace-only lines)
        if [[ -z "${line//[[:space:]]/}" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # Support optional leading "export" in the env file
        if [[ "$line" =~ ^[[:space:]]*export[[:space:]]+(.+) ]]; then
            line="${BASH_REMATCH[1]}"
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

list_secrets() {
    local env_file
    env_file="$(resolve_existing_env_file "$1")" || return $?

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty and comment lines (with or without leading whitespace)
        if [[ -z "${line//[[:space:]]/}" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # Capture key names with optional leading "export"
        if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([^=[:space:]]+)[[:space:]]*= ]]; then
            echo "${BASH_REMATCH[2]}"
        fi
    done < "$env_file"
}

interactive_select_secret() {
    local env_arg="$1"
    local env_file
    env_file="$(resolve_existing_env_file "$env_arg")" || return $?

    # Gather keys
    local keys=()
    while IFS= read -r key; do
        keys+=("$key")
    done < <(list_secrets "$env_arg")

    if [ "${#keys[@]}" -eq 0 ]; then
        echo "No keys found in $env_file" >&2
        return 1
    fi

    local choice=""
    if command -v fzf >/dev/null 2>&1; then
        choice="$(printf '%s\n' "${keys[@]}" | fzf --prompt="Select secret > " --height=20 --reverse --border)"
    elif command -v fzy >/dev/null 2>&1; then
        choice="$(printf '%s\n' "${keys[@]}" | fzy)"
    else
        echo "fzf/fzy not found; using numbered menu." >&2
        select key in "${keys[@]}"; do
            if [ -n "$key" ]; then
                choice="$key"
                break
            fi
        done
    fi

    if [ -z "$choice" ]; then
        echo "No selection made." >&2
        return 1
    fi

    # Load env quietly, then print the chosen value
    set_ai_env "$env_arg" > /dev/null 2>&1
    get_secret "$choice"
}

# Main script logic
interactive=0
clean_args=()
for arg in "$@"; do
    case "$arg" in
        -i|--interactive)
            interactive=1
            ;;
        *)
            clean_args+=("$arg")
            ;;
    esac
done
set -- "${clean_args[@]}"

if [ "$interactive" -eq 1 ]; then
    # Allow subcommand tokens to be present but ignore them for interactive mode.
    if [ "$#" -gt 0 ]; then
        case "$1" in
            list|get|set-env|--)
                shift
                ;;
        esac
    fi
    env_arg="${1-}"
    interactive_select_secret "$env_arg"
    exit $?
fi

if [ "$1" = "get" ]; then
    if [ -z "$2" ]; then
        echo "Error: Please specify a key to retrieve" >&2
        print_usage
        exit 1
    fi
    
    # First, set the environment variables quietly
    set_ai_env > /dev/null 2>&1
    
    # Then, get the requested secret
    get_secret "$2"
elif [ "$1" = "list" ]; then
    shift
    list_secrets "$@"
elif [ "$1" = "set-env" ]; then
    shift
    set_ai_env "$@"
else
    echo "Error: Unknown command" >&2
    print_usage
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
