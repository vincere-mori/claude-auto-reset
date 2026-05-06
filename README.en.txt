claude-auto-reset - which file to run
=====================================

Windows
-------

1) One-shot ping (check `claude` is on PATH):

   windows\ping-claude.bat

   Double-click or run from cmd.

2) Install Task Scheduler entry (every 4h 50m, task name claude-auto-reset):

   windows\schedule-install.bat

   Remove task:

   windows\schedule-remove.bat

   From cmd: ping-claude.bat schedule-install  /  ping-claude.bat schedule-remove

3) Limit cooldown + optional Task Scheduler retiming live under `windows\internal\`
   (do not run by hand). On limit, the task may switch to a one-shot run near the
   reset time. After a successful ping, `schedule-install` runs again to bring back
   the every-4h50m schedule when that one-shot mode was used.

Console messages from these .bat files are in English so they display correctly in
every Windows cmd code page.

Linux / macOS
-------------

One-shot: linux/ping-claude.sh or macos/ping-claude.sh.

Cron install/remove: cron-install / cron-remove on the same scripts.

See README.md for full notes (Russian). This file covers only which launcher to run.

