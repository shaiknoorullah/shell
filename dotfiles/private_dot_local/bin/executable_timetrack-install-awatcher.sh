#!/usr/bin/env bash
# Install the latest awatcher linux binary to ~/.local/bin/awatcher (idempotent).
#
# 2e3s/awatcher publishes TWO build flavors per release, with no linux/gnu/arch tag
# in the filename:
#   - "aw-awatcher*" = thin client: watchers only, reports to an EXTERNAL aw-server
#                      (what we want here — a standalone aw-server is already running
#                      as its own systemd service).
#   - "awatcher*"    = "bundle" build with its OWN embedded ActivityWatch server;
#                      it always tries to bind a server port on startup (confirmed via
#                      `--help`: "watcher with a bundled ActivityWatch server", and via
#                      a live AddrInUse panic when run against the already-running
#                      standalone aw-server) — it cannot coexist with a separate
#                      aw-server.service on the same port.
# Always prefer an "aw-awatcher" (thin-client) asset.
set -euo pipefail
DEST="$HOME/.local/bin/awatcher"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

api="https://api.github.com/repos/2e3s/awatcher/releases/latest"
assets="$(curl -fsSL "$api" | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4)"

bin=""
zip_url="$(echo "$assets" | grep -iE '/aw-awatcher\.zip$' | head -1 || true)"
if [ -n "$zip_url" ]; then
  echo "Using: $zip_url"
  cd "$TMP"; curl -fsSL -o dl.zip "$zip_url"; unzip -q dl.zip
  bin="$(find "$TMP" -maxdepth 2 -type f -name 'aw-awatcher' | head -1)"
fi

if [ -z "$bin" ]; then
  # No thin-client zip — fall back to the thin-client .deb.
  deb_url="$(echo "$assets" | grep -iE '/aw-awatcher[_-][^/]*\.deb$' | head -1 || true)"
  [ -n "$deb_url" ] || { echo "ERROR: no thin-client (aw-awatcher) asset on latest release"; exit 1; }
  echo "Using: $deb_url"
  cd "$TMP"; curl -fsSL -o pkg.deb "$deb_url"
  dpkg-deb -x pkg.deb "$TMP/debx"
  bin="$TMP/debx/usr/bin/aw-awatcher"
  [ -f "$bin" ] || bin="$TMP/debx/usr/bin/awatcher"
fi

[ -n "$bin" ] && [ -f "$bin" ] || { echo "ERROR: awatcher binary not found"; exit 1; }
install -m 0755 "$bin" "$DEST"
echo "Installed: $DEST"; "$DEST" --version 2>/dev/null || true
