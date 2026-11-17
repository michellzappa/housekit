#!/usr/bin/env bash
# Set the Apple signing and notarization secrets that release-mac.yml needs,
# on one or more app repos, from files on this Mac.
#
#   ./scripts/setup-release-secrets.sh \
#     --p12 ~/Desktop/DeveloperID.p12 \
#     --api-key ~/.appstoreconnect/private_keys/AuthKey_XXXX.p8 \
#     --api-key-id XXXX --api-issuer-id xxxxxxxx-xxxx-... \
#     michellzappa/clip michellzappa/lift
#
# It asks for the .p12 password without echoing it. Values go straight to
# `gh secret set` on stdin; nothing is printed or written to disk.
# The Sparkle key is separate: scripts/sparkle-key.sh.
set -euo pipefail
set +x

TEAM_ID="992N457T8D"
P12="" API_KEY="" API_KEY_ID="" API_ISSUER_ID=""
REPOS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --p12) P12="$2"; shift 2 ;;
    --api-key) API_KEY="$2"; shift 2 ;;
    --api-key-id) API_KEY_ID="$2"; shift 2 ;;
    --api-issuer-id) API_ISSUER_ID="$2"; shift 2 ;;
    --team-id) TEAM_ID="$2"; shift 2 ;;
    -*) echo "error: unknown option $1" >&2; exit 1 ;;
    *) REPOS+=("$1"); shift ;;
  esac
done
[[ -f "$P12" && -f "$API_KEY" && -n "$API_KEY_ID" && -n "$API_ISSUER_ID" && ${#REPOS[@]} -gt 0 ]] || {
  sed -n '2,13p' "$0" >&2; exit 1;
}

read -r -s -p "Password of $(basename "$P12"): " P12_PASSWORD
echo >&2

for repo in "${REPOS[@]}"; do
  base64 -i "$P12" | gh secret set APPLE_DEVELOPER_CERTIFICATE_P12_BASE64 -R "$repo"
  printf '%s' "$P12_PASSWORD" | gh secret set APPLE_DEVELOPER_CERTIFICATE_PASSWORD -R "$repo"
  base64 -i "$API_KEY" | gh secret set APPLE_API_PRIVATE_KEY_BASE64 -R "$repo"
  printf '%s' "$API_KEY_ID" | gh secret set APPLE_API_KEY_ID -R "$repo"
  printf '%s' "$API_ISSUER_ID" | gh secret set APPLE_API_ISSUER_ID -R "$repo"
  printf '%s' "$TEAM_ID" | gh secret set APPLE_TEAM_ID -R "$repo"
  echo "Set the Apple release secrets on $repo." >&2
done
unset P12_PASSWORD
