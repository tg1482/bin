#!/bin/bash

echo "$(date): Starting backup." >> ~/dev/logs/cronlogs.txt

# Navigate to the repository directory
cd ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Obsidian\ Notes || exit

# Ensure the script runs with the repository
git fetch origin

# Add all changes and commit them if there are any
git add .
if git diff-index --quiet HEAD --; then
    echo "$(date): No changes to commit." >> ~/dev/logs/cronlogs.txt
else
    git commit -m "Automatic backup $(date)"
    echo "$(date): Changes committed." >> ~/dev/logs/cronlogs.txt
    git push origin HEAD >> ~/dev/logs/cronlogs.txt
fi

echo "$(date): Backup completed." >> ~/dev/logs/cronlogs.txt
