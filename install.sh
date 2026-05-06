#!/bin/sh
# Если скачал zip или права слетели, один раз из корня репозитория:

set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
chmod +x "$ROOT/linux/ping-claude.sh" "$ROOT/macos/ping-claude.sh"

echo "ok: linux/ping-claude.sh и macos/ping-claude.sh можно вызывать напрямую"
