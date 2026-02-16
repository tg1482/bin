#!/bin/bash
# Unified Agent Notification Script
# Usage: echo '{"notification_type":"...","message":"..."}' | notify.sh <AgentName>

AGENT="${1:-Agent}"
INPUT=$(cat)

# Debug logging
echo "$(date -Iseconds) [$AGENT] $INPUT" >> ~/dev/bin/agents/notify.log

# Parse JSON
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
MESSAGE=$(echo "$INPUT" | jq -r '.message // ""')

# Dramatic titles + sounds by type
case "$NOTIFICATION_TYPE" in
  permission_prompt)
    TITLE="Hear Ye, Hear Ye!"
    SUBTITLE="$AGENT humbly beseeches your royal permission!"
    SOUND="Hero"
    ;;
  idle_prompt)
    TITLE="The Silence Grows Deafening!"
    SUBTITLE="$AGENT awaits in solemn patience for your glorious return!"
    SOUND="Submarine"
    ;;
  elicitation_dialog)
    TITLE="A Question of Great Import!"
    SUBTITLE="$AGENT poses a riddle most urgent — your wisdom is required!"
    SOUND="Glass"
    ;;
  session.error)
    TITLE="A Calamity Most Dire!"
    SUBTITLE="$AGENT has encountered a perilous error and seeks your counsel!"
    SOUND="Funk"
    ;;
  *)
    TITLE="Hark! A Summons!"
    SUBTITLE="$AGENT beckons from the depths of your terminal!"
    SOUND="Funk"
    ;;
esac

BODY="${MESSAGE:-$SUBTITLE}"

# Click → focus the originating iTerm2 session
FOCUS_CMD='tell application "iTerm2" to activate'
if [[ -n "$ITERM_SESSION_ID" ]]; then
  UUID="${ITERM_SESSION_ID##*:}"
  FOCUS_CMD=$(cat <<EOF
tell application "iTerm2"
  activate
  repeat with w in windows
    repeat with t in tabs of w
      repeat with s in sessions of t
        if id of s is "$UUID" then
          select t
          select s
          return
        end if
      end repeat
    end repeat
  end repeat
end tell
EOF
)
fi

terminal-notifier \
  -title "$TITLE" \
  -subtitle "$AGENT" \
  -message "$BODY" \
  -sound "$SOUND" \
  -group "$AGENT-notify" \
  -execute "osascript -e '$(echo "$FOCUS_CMD" | sed "s/'/'\\''/g")'" \
  2>/dev/null &

exit 0
