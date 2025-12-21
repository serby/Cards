#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="card-barcodes"

if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
  echo "Error: CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID must be set"
  exit 1
fi

echo "Deploying to Cloudflare Pages..."
npx wrangler pages deploy "$SCRIPT_DIR/src" --project-name="$PROJECT_NAME"
echo "Deploy complete!"
