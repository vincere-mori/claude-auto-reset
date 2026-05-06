#!/bin/sh
# macOS: launchd or crontab, your choice
# if claude not in PATH: export CLAUDE_EXE=/full/path/to/claude
# Newer macOS may restrict cron; use launchd or grant Full Disk Access to cron/Terminal if needed

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
shell_self="${script_dir}/$(basename "$0")"

case "${1:-}" in
cron-install)
    tmp="$(mktemp)"
    crontab -l 2>/dev/null | awk '
      /^# BEGIN claude-auto-reset$/ {skip=1;next}
      /^# END claude-auto-reset$/ {skip=0;next}
      !skip {print}
    ' > "$tmp" || true
    {
      cat "$tmp"
      printf '%s\n' "# BEGIN claude-auto-reset"
      printf '%s\n' "0 */4 * * * $shell_self run >> /tmp/claude-auto-reset.log 2>&1"
      printf '%s\n' "# END claude-auto-reset"
    } | crontab -
    rm -f "$tmp"
    echo "ok: cron block added, every 4 h, log /tmp/claude-auto-reset.log"
    echo "remove: $0 cron-remove"
    exit 0
    ;;
cron-remove)
    tmp="$(mktemp)"
    crontab -l 2>/dev/null | awk '
      /^# BEGIN claude-auto-reset$/ {skip=1;next}
      /^# END claude-auto-reset$/ {skip=0;next}
      !skip {print}
    ' > "$tmp" || true
    if [ ! -s "$tmp" ]; then
      rm -f "$tmp"
      crontab -r 2>/dev/null || true
      echo "ok, crontab empty after removing block"
      exit 0
    fi
    crontab "$tmp"
    rm -f "$tmp"
    echo "ok, claude-auto-reset block removed from crontab"
    exit 0
    ;;
run)
    ;;
*)
    ;;
esac

msg="."
tries=3
wait=30
cc="${CLAUDE_EXE:-claude}"

i=0
while [ "$i" -lt "$tries" ]; do
  i=$((i + 1))
  echo "$(date '+%Y-%m-%d %H:%M:%S')  attempt $i"

  "$cc" -p "$msg" --output-format text </dev/null
  st=$?
  if [ "$st" -eq 0 ]; then
    echo ok
    exit 0
  fi
  echo "fail, exit code $st"
  [ "$i" -lt "$tries" ] || exit 1
  sleep "$wait"
done
exit 1
