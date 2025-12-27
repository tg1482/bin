#!/bin/bash

export HOME=/Users/tanmaygupta  # Replace with your actual username
LOG_FILE=$HOME/dev/logs/cronlogs.txt
export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_ed25519"  # Specify SSH key explicitly

OBSIDIAN_PATH="$HOME/dev/obsidian-notes"

# Add extensive debugging
echo "$(date): Starting backup." >> "$LOG_FILE"

cd "$OBSIDIAN_PATH" || {
    echo "$(date): Failed to change directory" >> "$LOG_FILE"
    exit 1
}

# Pull changes from remote repository
if git pull origin 2> /tmp/git_pull_error.txt; then
    echo "$(date): Successfully pulled changes from remote." >> "$LOG_FILE"
else
    # Check if the error contains merge conflict indicators
    if grep -q "CONFLICT\|Automatic merge failed" /tmp/git_pull_error.txt; then
        error_msg=$(cat /tmp/git_pull_error.txt)
        echo "$(date): MERGE CONFLICT DETECTED: $error_msg" >> "$LOG_FILE"
        
        # Send notification email
        echo "Merge conflict detected in your Obsidian backup at $(date)" | mail -s "Obsidian Backup Conflict Alert" tg1482@nyu.edu
        
        # If on macOS, you can also send a system notification:
        osascript -e 'display notification "Merge conflicts detected in Obsidian backup" with title "Git Backup Alert"'
    else
        echo "$(date): Failed to pull changes from remote." >> "$LOG_FILE"
    fi
    
    # Append the actual error to the log
    cat /tmp/git_pull_error.txt >> "$LOG_FILE"
    rm /tmp/git_pull_error.txt
fi

# Add all changes and commit them if there are any
git add .
if git diff-index --quiet HEAD --; then
    echo "$(date): No changes to commit." >> "$LOG_FILE"
else
    git commit -m "Automatic backup $(date)" 2>> "$LOG_FILE"
    echo "$(date): Changes committed." >> "$LOG_FILE"
    
    # Push with error logging
    if git push origin HEAD 2>> "$LOG_FILE"; then
        echo "$(date): Successfully pushed changes." >> "$LOG_FILE"
    else
        echo "$(date): Failed to push changes." >> "$LOG_FILE"
    fi
fi

echo "$(date): Backup completed." >> "$LOG_FILE"
