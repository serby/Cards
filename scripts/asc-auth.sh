#!/bin/bash
# Generates a JWT for App Store Connect API
# Sources: ASC_KEY_ID, ASC_ISSUER_ID, and the .p8 key file
# Usage: source scripts/asc-auth.sh

KEY_DIR="${API_PRIVATE_KEYS_DIR:-$HOME/.appstoreconnect/private_keys}"
KEY_FILE="$KEY_DIR/AuthKey_${ASC_KEY_ID}.p8"

if [[ ! -f "$KEY_FILE" && -n "${ASC_KEY_CONTENT:-}" ]]; then
    mkdir -p "$KEY_DIR"
    echo "$ASC_KEY_CONTENT" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
fi

if [[ ! -f "$KEY_FILE" ]]; then
    echo "Error: API key not found at $KEY_FILE" >&2
    echo "Set ASC_KEY_CONTENT env var or place the .p8 file manually." >&2
    exit 1
fi

# Base64url encode
b64url() { openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'; }

HEADER=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$ASC_KEY_ID" | b64url)
NOW=$(date +%s)
EXP=$((NOW + 1200))
PAYLOAD=$(printf '{"iss":"%s","exp":%d,"aud":"appstoreconnect-v1"}' "$ASC_ISSUER_ID" "$EXP" | b64url)

# openssl dgst emits an ASN.1/DER-encoded ECDSA signature; the JWT ES256 spec
# requires the raw r||s concatenation (64 bytes for P-256). Without this
# conversion App Store Connect returns 401 NOT_AUTHORIZED.
SIGNATURE=$(printf '%s.%s' "$HEADER" "$PAYLOAD" \
    | openssl dgst -sha256 -sign "$KEY_FILE" \
    | python3 -c '
import sys
der = sys.stdin.buffer.read()
# Minimal DER ECDSA-Sig decode: SEQ { INTEGER r, INTEGER s }
assert der[0] == 0x30
i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7f)
def take_int(buf, idx):
    assert buf[idx] == 0x02
    length = buf[idx+1]
    val = buf[idx+2:idx+2+length]
    # Strip a single leading 0x00 sign byte if present
    if len(val) > 32 and val[0] == 0x00:
        val = val[1:]
    # Left-pad to 32 bytes
    return val.rjust(32, b"\x00"), idx + 2 + length
r, i = take_int(der, i)
s, _ = take_int(der, i)
sys.stdout.buffer.write(r + s)
' \
    | b64url)

export ASC_JWT="$HEADER.$PAYLOAD.$SIGNATURE"
export ASC_API="https://api.appstoreconnect.apple.com/v1"
