#!/bin/bash

BIN_DIR="/usr/local/bin"

link_script() {
    local script="$1"
    local script_path
    local link_name
    
    if [[ "$script" = /* ]]; then
        # It's an absolute path
        script_path="$script"
    else
        # It's a relative path
        script_path="$(pwd)/$script"
    fi
    
    if [ ! -f "$script_path" ]; then
        echo "Error: Script $script not found"
        exit 1
    fi
    
    # Remove .sh extension for the link name
    link_name=$(basename "$script" .sh)
    
    if [ -L "$BIN_DIR/$link_name" ]; then
        echo "Warning: A link named $link_name already exists in $BIN_DIR"
        read -p "Do you want to overwrite it? (y/n) " -n 1 -r
        echo    # move to a new line
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            exit 1
        fi
        rm "$BIN_DIR/$link_name"
    elif [ -e "$BIN_DIR/$link_name" ]; then
        echo "Error: A file named $link_name already exists in $BIN_DIR and is not a symlink"
        exit 1
    fi
    
    chmod +x "$script_path"
    ln -s "$script_path" "$BIN_DIR/$link_name"
    echo "Linked $script_path to $BIN_DIR/$link_name"
}

unlink_script() {
    local script="$1"
    local link_name=$(basename "$script" .sh)
    if [ -L "$BIN_DIR/$link_name" ]; then
        rm "$BIN_DIR/$link_name"
        echo "Unlinked $link_name from $BIN_DIR"
    else
        echo "Error: $link_name is not linked in $BIN_DIR"
    fi
}

case "$1" in
    link)
        if [ -z "$2" ]; then
            echo "Usage: $(basename $0) link <script_name_or_path>"
            exit 1
        fi
        link_script "$2"
        ;;
    unlink)
        if [ -z "$2" ]; then
            echo "Usage: $(basename $0) unlink <script_name>"
            exit 1
        fi
        unlink_script "$2"
        ;;
    *)
        echo "Usage: $(basename $0) {link|unlink} <script_name_or_path>"
        exit 1
        ;;
esac