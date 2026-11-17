#!/usr/bin/env bash
# Give a repo its own Sparkle EdDSA key pair, once, and print the public key.
#
#   ./scripts/sparkle-key.sh michellzappa/tessellate
#
# The private key goes to two places and nowhere else:
#   - the repo's GitHub Actions secret SPARKLE_PRIVATE_ED_KEY (release signing)
#   - the login keychain, service https://sparkle-project.org, account
#     <owner/repo> (the backup; Sparkle's own generate_keys --account reads it)
# It is never printed, logged or written to a file.
#
# Run it again and it reuses the keychain key: it prints the same public key
# and sets the secret again. Put the public key in the app's Info.plist as
# SUPublicEDKey. A lost private key means every installed copy stops
# updating, so keep the keychain item.
set -euo pipefail
set +x

REPO="${1:?usage: sparkle-key.sh owner/repo}"
SERVICE="https://sparkle-project.org"

command -v openssl >/dev/null || { echo "error: openssl is required" >&2; exit 1; }
openssl version | grep -q '^OpenSSL 3' || { echo "error: needs OpenSSL 3 (Homebrew), not LibreSSL" >&2; exit 1; }

seed=""
if seed=$(security find-generic-password -s "$SERVICE" -a "$REPO" -w 2>/dev/null); then
  echo "Reusing the keychain key for $REPO." >&2
else
  pem=$(openssl genpkey -algorithm ed25519 2>/dev/null)
  seed=$(printf '%s\n' "$pem" | openssl pkey -outform DER | tail -c 32 | base64)
  unset pem
  security add-generic-password -s "$SERVICE" -a "$REPO" \
    -l "Sparkle EdDSA key for $REPO" -D "private key" -w "$seed"
  echo "Stored a new key for $REPO in the login keychain." >&2
fi

[[ "$(printf '%s' "$seed" | base64 --decode | wc -c | tr -d ' ')" == 32 ]] \
  || { echo "error: the keychain item for $REPO is not a 32-byte Ed25519 seed" >&2; exit 1; }

# PKCS#8 header for a raw Ed25519 private key, then the seed.
public=$( { printf '\x30\x2e\x02\x01\x00\x30\x05\x06\x03\x2b\x65\x70\x04\x22\x04\x20'; printf '%s' "$seed" | base64 --decode; } \
  | openssl pkey -inform DER -pubout -outform DER | tail -c 32 | base64)

printf '%s' "$seed" | gh secret set SPARKLE_PRIVATE_ED_KEY -R "$REPO" >/dev/null
unset seed
echo "Set SPARKLE_PRIVATE_ED_KEY on $REPO." >&2
echo "$public"
