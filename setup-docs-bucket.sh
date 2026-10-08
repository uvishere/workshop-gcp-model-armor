#!/usr/bin/env bash
#
# One-time setup: creates the GCS bucket of SecureBank's "internal documents"
# (codelab step 03, and slide 7 of the talk).
#
# Uploads the copies from app/docs/. One of them, complaint-4471.txt, has
# attacker instructions written into the complaint body: that is the indirect
# prompt injection attendees find in step 04.
#
# app/server.js and presentation/proxy.js both read these once at startup. If
# the bucket is missing or unreadable they fall back to the local app/docs/
# copies, so the app still runs. Running this script is what makes it real.
#
# The bucket holds fabricated PII, so it is created with public access
# prevention on. Nothing here should ever be reachable without auth.
#
# Usage:  ./setup-docs-bucket.sh
#
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
set -a
# shellcheck source=/dev/null
source "$DIR/app/.env"
set +a

PROJECT="${GOOGLE_CLOUD_PROJECT:?GOOGLE_CLOUD_PROJECT not set in app/.env}"
LOCATION="${GOOGLE_CLOUD_LOCATION:-us-central1}"
BUCKET="${SECUREBANK_DOCS_BUCKET:-${PROJECT}-securebank-docs}"

if ! gcloud storage buckets describe "gs://${BUCKET}" --project "$PROJECT" >/dev/null 2>&1; then
  echo "Creating gs://${BUCKET} in ${LOCATION}…"
  gcloud storage buckets create "gs://${BUCKET}" \
    --project "$PROJECT" \
    --location "$LOCATION" \
    --uniform-bucket-level-access \
    --public-access-prevention
else
  echo "Bucket gs://${BUCKET} already exists — reusing it."
fi

echo "Uploading documents…"
gcloud storage cp "$DIR"/app/docs/*.txt "gs://${BUCKET}/" --project "$PROJECT"

echo
echo "✅  Done. Documents in gs://${BUCKET}:"
gcloud storage ls "gs://${BUCKET}" --project "$PROJECT"
echo
echo "Add this line to app/.env if it is not already there:"
echo
echo "SECUREBANK_DOCS_BUCKET=${BUCKET}"
