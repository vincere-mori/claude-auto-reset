claude-auto-reset - which file to run
=====================================

Windows
-------

1) One-shot ping (check `claude` is on PATH):

   windows\ping-claude.bat

   Double-click or run from cmd.

2) Install Task Scheduler entry (every 4 hours, task name claude-auto-reset):

   windows\schedule-install.bat

   Remove task:

   windows\schedule-remove.bat

   From cmd: ping-claude.bat schedule-install  /  ping-claude.bat schedule-remove

3) Limit cooldown is handled by `windows\internal\` (do not run those scripts by
   hand; only ping-claude.bat calls them — parses replies like «resets …»).

Console messages from these .bat files are in English so they display correctly in
every Windows cmd code page.

Linux / macOS
-------------

One-shot: linux/ping-claude.sh or macos/ping-claude.sh.

Cron install/remove: cron-install / cron-remove on the same scripts.

See README.md for full notes (Russian). This file covers only which launcher to run.

