#!/usr/bin/env bash
#
# Deploys the talk to Cloud Run: the deck and its live demos as one service.
#
#   ./presentation/deploy.sh
#
# The proxy serves presentation.html and the chat routes from the same URL.
# Every page asks for a password (any username). It lives in Secret Manager;
# read it with the command this script prints at the end.
#
# Safe to re-run: the service account, its roles and the password are only
# created the first time. Each run redeploys the current deck.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/app/.env"
[ -f "$ENV_FILE" ] || { echo "❌ $ENV_FILE not found (it holds the project and Model Armor templates)" >&2; exit 1; }
set -a; source "$ENV_FILE"; set +a

PROJECT="${GOOGLE_CLOUD_PROJECT:?GOOGLE_CLOUD_PROJECT missing from app/.env}"
REGION="${DECK_REGION:-us-central1}"
SERVICE="${DECK_SERVICE:-securebank-talk}"
SA_NAME="${DECK_SA:-securebank-talk}"
SA="$SA_NAME@$PROJECT.iam.gserviceaccount.com"
SECRET="${DECK_SECRET:-securebank-talk-password}"
G="gcloud --project $PROJECT --quiet"

echo "▶ Project $PROJECT · service $SERVICE · region $REGION"

# ── One-time setup ───────────────────────────────────────────────────────────
if ! $G iam service-accounts describe "$SA" >/dev/null 2>&1; then
  echo "▶ Creating service account $SA"
  $G iam service-accounts create "$SA_NAME" --display-name "SecureBank talk (deck + live demos)"
fi
# Only what the demos call: Gemini, and Model Armor (which runs SDP for us).
for role in roles/aiplatform.user roles/modelarmor.user; do
  $G projects add-iam-policy-binding "$PROJECT" --member "serviceAccount:$SA" \
    --role "$role" --condition None >/dev/null
done

if ! $G secrets describe "$SECRET" >/dev/null 2>&1; then
  echo "▶ Creating the deck password in Secret Manager ($SECRET)"
  openssl rand -base64 18 | tr -d '/+=\n' | $G secrets create "$SECRET" --data-file=- --replication-policy automatic
fi
$G secrets add-iam-policy-binding "$SECRET" --member "serviceAccount:$SA" \
  --role roles/secretmanager.secretAccessor >/dev/null

# ── Stage only what the service needs ────────────────────────────────────────
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/app/docs" "$BUILD/presentation/fonts"
cp "$ROOT/app/knowledgebase.txt" "$BUILD/app/"
cp "$ROOT"/app/docs/*.txt "$BUILD/app/docs/"
cp "$ROOT"/presentation/{proxy.js,presentation.html,codelab-qr.png} "$BUILD/presentation/"
cp "$ROOT"/presentation/fonts/*.woff2 "$BUILD/presentation/fonts/"
cp "$ROOT/presentation/Dockerfile" "$BUILD/"

# ── Deploy ───────────────────────────────────────────────────────────────────
# Public at the network level; the proxy's own password gate does the rest.
# Max 2 instances caps what a leaked password could cost.
$G run deploy "$SERVICE" \
  --source "$BUILD" \
  --region "$REGION" \
  --service-account "$SA" \
  --allow-unauthenticated \
  --set-env-vars "GOOGLE_CLOUD_PROJECT=$PROJECT,GOOGLE_CLOUD_LOCATION=${GOOGLE_CLOUD_LOCATION:-us-central1},MODEL_ARMOR_TEMPLATE=${MODEL_ARMOR_TEMPLATE},MODEL_ARMOR_TEMPLATE_REDACT=${MODEL_ARMOR_TEMPLATE_REDACT:-$MODEL_ARMOR_TEMPLATE}" \
  --set-secrets "DECK_PASSWORD=$SECRET:latest" \
  --min-instances 0 --max-instances 2 \
  --memory 512Mi --timeout 120

URL="$($G run services describe "$SERVICE" --region "$REGION" --format 'value(status.url)')"
echo
echo "✅ Deck: $URL"
echo "   Password (any username):"
echo "   gcloud secrets versions access latest --secret $SECRET --project $PROJECT"
