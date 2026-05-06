#!/bin/sh
# If you used zip download or chmod was lost: run once from repo root:

set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
chmod +x "$ROOT/linux/ping-claude.sh" "$ROOT/macos/ping-claude.sh"

echo "ok: linux/ping-claude.sh and macos/ping-claude.sh are now executable"
