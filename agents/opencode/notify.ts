import { execSync } from "child_process";

// Only notify on events that genuinely need user attention
const NOTIFY_EVENTS: Record<string, string> = {
  "session.error": "session.error",
};

export const DramaticNotifyPlugin = async () => ({
  event: async ({ event }: { event: { type: string } }) => {
    const type = NOTIFY_EVENTS[event.type];
    if (!type) return;
    const payload = JSON.stringify({ notification_type: type });
    try {
      execSync(`echo '${payload}' | /Users/tanmaygupta/dev/bin/agents/notify.sh OpenCode`, {
        timeout: 10000,
      });
    } catch {}
  },
});
