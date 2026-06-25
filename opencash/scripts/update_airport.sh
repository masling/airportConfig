#!/bin/sh
set -eu

TARGET="/etc/openclash/proxy_provider/airport.yaml"
LEGACY_TARGET="/etc/openclash/providers/airport.yaml"
DEFAULT_SOURCE="/etc/openclash/config/ssrdog.yaml"
DIR="$(dirname "$TARGET")"
LEGACY_DIR="$(dirname "$LEGACY_TARGET")"

if [ "$#" -eq 0 ] && [ -f "$DEFAULT_SOURCE" ]; then
  INPUT="$DEFAULT_SOURCE"
elif [ "$#" -eq 1 ] && [ -n "${1:-}" ]; then
  INPUT="$1"
else
  echo "Usage: sh /root/update_airport.sh [new-5-minute-subscription-url-or-local-yaml]" >&2
  echo "Default file: $DEFAULT_SOURCE" >&2
  echo "Example URL:  sh /root/update_airport.sh \"https://example.com/sub?token=...\"" >&2
  echo "Example file: sh /root/update_airport.sh /root/ssrdog.yaml" >&2
  exit 2
fi

TMP="${TARGET}.tmp.$$"

cleanup() {
  rm -f "$TMP"
}
trap cleanup EXIT INT TERM

mkdir -p "$DIR"
mkdir -p "$LEGACY_DIR"

case "$INPUT" in
  http://*|https://*)
    if command -v curl >/dev/null 2>&1; then
      curl -L --connect-timeout 15 --max-time 120 --retry 2 -A "clash.meta" -o "$TMP" "$INPUT"
    elif command -v wget >/dev/null 2>&1; then
      wget -T 120 -U "clash.meta" -O "$TMP" "$INPUT"
    else
      echo "Neither curl nor wget is available." >&2
      exit 1
    fi
    ;;
  *)
    if [ ! -f "$INPUT" ]; then
      echo "Local YAML file not found: $INPUT" >&2
      exit 1
    fi
    cp "$INPUT" "$TMP"
    ;;
esac

if [ ! -s "$TMP" ]; then
  echo "Input YAML is empty; keeping old provider." >&2
  exit 1
fi

if ! grep -Eq '^[[:space:]]*(proxies:|proxy-providers:)|^[[:space:]]*type:[[:space:]]*anytls([[:space:]]|$)' "$TMP"; then
  echo "Input YAML does not look like a Clash/Mihomo provider; keeping old provider." >&2
  exit 1
fi

chmod 600 "$TMP"
mv "$TMP" "$TARGET"
cp "$TARGET" "$LEGACY_TARGET"
chmod 600 "$LEGACY_TARGET"
trap - EXIT INT TERM

echo "Source $INPUT"
echo "Updated $TARGET"
echo "Updated compatibility copy $LEGACY_TARGET"

if [ -x /etc/init.d/openclash ]; then
  /etc/init.d/openclash restart
else
  echo "/etc/init.d/openclash not found; please restart OpenClash manually." >&2
fi
