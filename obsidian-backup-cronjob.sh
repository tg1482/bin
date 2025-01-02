#!/bin/bash

# Navigate to the repository directory
cd ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Obsidian\ Notes || exit

# Ensure the script runs with the repository
git fetch origin

# Compare local branch with the remote
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse @{u})

if [ "$LOCAL" != "$REMOTE" ]; then
    # Push local changes to remote
    git push origin HEAD
    echo "$(date): Changes pushed to remote." >> ~/dev/logs/cronlogs.txt
else
    echo "$(date): No changes to push." >> ~/dev/logs/cronlogs.txt
fi

