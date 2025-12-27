#!/bin/bash

export HOME=/Users/tanmaygupta  # Replace with your actual username
LOG_FILE=$HOME/dev/logs/cronlogs.txt
export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_ed25519"  # Specify SSH key explicitly

OBSIDIAN_PATH="$HOME/dev/obsidian-notes"

today_start() {
    if command -v gdate >/dev/null 2>&1; then
        gdate -d "today 00:00" +"%Y-%m-%d %H:%M:%S"
    else
        date -v0H -v0M -v0S +"%Y-%m-%d %H:%M:%S"
    fi
}

daily_base_commit() {
    local start_ts="$1"
    # Last commit strictly before start of today; fallback to repo root if none
    local base
    base=$(git rev-list -1 --before="$start_ts" HEAD 2>/dev/null || true)
    if [ -z "$base" ]; then
        base=$(git rev-list --max-parents=0 HEAD 2>/dev/null || true)
    fi
    echo "$base"
}

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

# Squash all of today's commits into one daily commit (local history rewrite)
start_of_day="$(today_start)"
base_commit="$(daily_base_commit "$start_of_day")"
if [ -n "$base_commit" ]; then
    commits_today=$(git rev-list --count "${base_commit}..HEAD")
    if [ "$commits_today" -gt 1 ]; then
        # Only squash if there are multiple commits today AND the tree changed
        if git diff --quiet "$base_commit" HEAD; then
            echo "$(date): No tree changes since $start_of_day; skipping squash." >> "$LOG_FILE"
        else
            echo "$(date): Squashing $commits_today commits since $start_of_day" >> "$LOG_FILE"
            git reset --soft "$base_commit"
        fi
    elif [ "$commits_today" -eq 1 ]; then
        echo "$(date): Already a single commit for today; skipping squash." >> "$LOG_FILE"
    else
        echo "$(date): No commits to squash after $start_of_day" >> "$LOG_FILE"
    fi
else
    echo "$(date): Could not determine base commit for squashing" >> "$LOG_FILE"
fi

# Add all changes and commit them if there are any
git add .
if git diff-index --quiet HEAD --; then
    echo "$(date): No changes to commit." >> "$LOG_FILE"
else
    git commit -m "Automatic backup $(date)" 2>> "$LOG_FILE"
    echo "$(date): Changes committed." >> "$LOG_FILE"
    
    # Push with error logging
    if git push --force-with-lease origin HEAD 2>> "$LOG_FILE"; then
        echo "$(date): Successfully pushed changes (force-with-lease)." >> "$LOG_FILE"
    else
        echo "$(date): Failed to push changes (force-with-lease)." >> "$LOG_FILE"
    fi
fi

echo "$(date): Backup completed." >> "$LOG_FILE"
