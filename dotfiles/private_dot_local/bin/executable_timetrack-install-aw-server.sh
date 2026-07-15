#!/usr/bin/env bash
# Install the latest aw-server-rust linux binary to ~/.local/bin/aw-server (idempotent).
set -euo pipefail
DEST="$HOME/.local/bin/aw-server"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

url="$(curl -fsSL https://api.github.com/repos/ActivityWatch/aw-server-rust/releases/latest 2>/dev/null \
  | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4 \
  | grep -iE 'x86[_-]64.*linux|linux.*x86[_-]64' | grep -iE '\.zip$|\.tar\.gz$' | head -1 || true)"

if [ -z "$url" ]; then
  # aw-server-rust ships no releases of its own anymore (repo has zero entries under
  # /releases) — it's built and released as part of the full ActivityWatch bundle.
  # That bundle's linux zip still contains the standalone Rust binary at
  # activitywatch/aw-server-rust/aw-server-rust (dynamically linked only against glibc,
  # no other bundle assets required), so fall back to it.
  echo "No asset on aw-server-rust releases/latest; falling back to ActivityWatch/activitywatch bundle release"
  url="$(curl -fsSL https://api.github.com/repos/ActivityWatch/activitywatch/releases/latest \
    | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4 \
    | grep -iE 'x86[_-]64.*linux|linux.*x86[_-]64' | grep -iE '\.zip$|\.tar\.gz$' | head -1)"
fi
[ -n "$url" ] || { echo "ERROR: no linux x86_64 asset found on either release"; exit 1; }
echo "Downloading: $url"
cd "$TMP"
curl -fsSL -o pkg "$url"
case "$url" in *.zip) unzip -q pkg ;; *.tar.gz) tar xzf pkg ;; esac

bin="$(find "$TMP" -type f -perm -u+x -name 'aw-server-rust' | head -1)"
[ -n "$bin" ] || bin="$(find "$TMP" -type f -perm -u+x -name 'aw-server' | head -1)"
[ -n "$bin" ] || bin="$(find "$TMP" -type f -name 'aw-server*' ! -name '*.zip' ! -name '*.tar.gz' ! -name '*.service' | head -1)"
[ -n "$bin" ] || { echo "ERROR: aw-server binary not found in archive"; exit 1; }

install -m 0755 "$bin" "$DEST"
echo "Installed: $DEST"; "$DEST" --version 2>/dev/null || true
