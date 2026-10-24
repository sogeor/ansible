#!/usr/bin/env bash
# Render files/user-data.yaml for one host into RAM (/dev/shm) and copy it to the Windows clipboard.
# Usage: scripts/render-user-data.sh <hostname> [domain]
# Needs: Bitwarden unlocked (bwu) and ~/.config/sogeor/bw.sh.
set -euo pipefail
. ~/.config/sogeor/bw.sh

HOST="${1:?hostname}"
DOMAIN="${2:-sogeor.com}"
[[ "$HOST" =~ ^[a-z][a-z0-9-]{0,62}$ ]] || { echo "invalid hostname: $HOST" >&2; exit 1; }

dir="$(cd "$(dirname "$0")/.." && pwd)"
ca="$(bw_note sogeor/ssh/user_ca.pub | head -1)"
bg="$(bw_note sogeor/ssh/break_glass.pub | head -1)"
[ -n "$ca" ] && [ -n "$bg" ] || { echo "keys not found in Bitwarden" >&2; exit 1; }

out="/dev/shm/user-data-$HOST.yaml"
sed -e "s|HOSTNAME|$HOST|g" -e "s|DOMAIN|$DOMAIN|g" \
    -e "s|USER_CA_PUBKEY|$ca|" -e "s|BREAK_GLASS_PUBKEY|$bg|" \
    "$dir/files/user-data.yaml" > "$out"

if grep -nE 'HOSTNAME|DOMAIN|USER_CA_PUBKEY|BREAK_GLASS_PUBKEY' "$out"; then
  echo "placeholders left in $out" >&2; exit 1
fi
python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$out"
if command -v cloud-init >/dev/null; then cloud-init schema -c "$out"; fi

command -v clip.exe >/dev/null && clip.exe < "$out" && echo "copied to clipboard"
echo "$out"
