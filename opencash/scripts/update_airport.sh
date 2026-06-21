#!/bin/sh
set -eu

TARGET="/etc/openclash/proxy_provider/airport.yaml"
LEGACY_TARGET="/etc/openclash/providers/airport.yaml"
DIR="$(dirname "$TARGET")"
LEGACY_DIR="$(dirname "$LEGACY_TARGET")"

if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
  echo "Usage: sh /root/update_airport.sh \"new-5-minute-subscription-url\"" >&2
  exit 2
fi

URL="$1"
TMP="${TARGET}.tmp.$$"

cleanup() {
  rm -f "$TMP"
}
trap cleanup EXIT INT TERM

mkdir -p "$DIR"
mkdir -p "$LEGACY_DIR"

if command -v curl >/dev/null 2>&1; then
  curl -L --connect-timeout 15 --max-time 120 --retry 2 -A "clash.meta" -o "$TMP" "$URL"
elif command -v wget >/dev/null 2>&1; then
  wget -T 120 -U "clash.meta" -O "$TMP" "$URL"
else
  echo "Neither curl nor wget is available." >&2
  exit 1
fi

if [ ! -s "$TMP" ]; then
  echo "Downloaded file is empty; keeping old provider." >&2
  exit 1
fi

if ! grep -Eq '^[[:space:]]*(proxies:|proxy-providers:)|^[[:space:]]*type:[[:space:]]*anytls([[:space:]]|$)' "$TMP"; then
  echo "Downloaded file does not look like a Clash/Mihomo provider; keeping old provider." >&2
  exit 1
fi

chmod 600 "$TMP"
mv "$TMP" "$TARGET"
cp "$TARGET" "$LEGACY_TARGET"
chmod 600 "$LEGACY_TARGET"
trap - EXIT INT TERM

echo "Updated $TARGET"
echo "Updated compatibility copy $LEGACY_TARGET"

if [ -x /etc/init.d/openclash ]; then
  /etc/init.d/openclash restart
else
  echo "/etc/init.d/openclash not found; please restart OpenClash manually." >&2
fi
