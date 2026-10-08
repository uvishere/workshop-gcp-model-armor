#!/usr/bin/env bash
#
# Publishes docs/codelab.md to https://codelabs.uvishere.com/secure-ai-with-armor
#
# The Cloud Run service serves the claat export from its web root, and a
# Cloudflare route maps /secure-ai-with-armor onto it. So the codelab id in
# codelab.md does not need to match the URL; only the service name does.
#
# Needs claat (go install github.com/googlecodelabs/tools/claat@latest).
#
# Usage:  ./docs/site/deploy.sh
#
set -euo pipefail

PROJECT="${CODELAB_PROJECT:-gdg-secure-ai-workshop}"
SERVICE="${CODELAB_SERVICE:-workshop-codelab}"
REGION="${CODELAB_REGION:-us-central1}"

SITE_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCS_DIR="$(dirname "$SITE_DIR")"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# claat resolves images/ relative to the markdown, so export from docs/.
(cd "$DOCS_DIR" && claat export -o "$BUILD/export" codelab.md)
cp "$SITE_DIR/Dockerfile" "$SITE_DIR/nginx.conf" "$BUILD/"
mv "$BUILD"/export/* "$BUILD/site"
# claat on Windows writes image paths with backslashes (img\\abc.png). Chrome
# happens to cope; other browsers and crawlers need real URL paths.
sed -i 's#img[\\]\{1,\}#img/#g' "$BUILD/site/index.html"
if grep -qF 'img\' "$BUILD/site/index.html"; then
  echo "❌ Image paths still contain backslashes" >&2
  exit 1
fi

gcloud run deploy "$SERVICE" \
  --source "$BUILD" \
  --region "$REGION" \
  --project "$PROJECT" \
  --allow-unauthenticated \
  --quiet
