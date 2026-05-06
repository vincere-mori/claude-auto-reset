#!/bin/sh
# то же что на винде - кроном дёргать раз в пару часов
# export CLAUDE_EXE=/путь/к/claude если не в PATH

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
    echo "ок: добавлен блок в crontab, каждые 4 ч, лог /tmp/claude-auto-reset.log"
    echo "снять: $0 cron-remove"
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
      echo ок, cron пуст после удаления блока
      exit 0
    fi
    crontab "$tmp"
    rm -f "$tmp"
    echo ок, блок claude-auto-reset убран из crontab
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
  echo "$(date '+%Y-%m-%d %H:%M:%S')  попытка $i"

  "$cc" -p "$msg" --output-format text </dev/null
  st=$?
  if [ "$st" -eq 0 ]; then
    echo норм
    exit 0
  fi
  echo не вышло, код "$st"
  [ "$i" -lt "$tries" ] || exit 1
  sleep "$wait"
done
exit 1
