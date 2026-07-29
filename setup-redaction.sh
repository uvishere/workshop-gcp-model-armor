#!/usr/bin/env bash
#
# One-time setup for the slide 14 redaction demo.
#
# Model Armor can only hand back masked text when its template uses ADVANCED
# Sensitive Data Protection — that means pointing it at a DLP inspect template
# AND a DLP de-identify template. Basic SDP only tells you PII is present.
#
# Creates:
#   1. a DLP inspect template     (what to look for)
#   2. a DLP de-identify template (what to replace it with)
#   3. a Model Armor template wired to both
#
# Then prints the MODEL_ARMOR_TEMPLATE_REDACT line to add to app/.env.
#
# Two gotchas this script works around, both of which cost real debugging time:
#
#   * QUOTA PROJECT. `gcloud auth print-access-token` returns a *user* credential
#     with no quota project attached, so DLP returns 403 "requires a quota
#     project". Every call below sends an explicit x-goog-user-project header.
#
#   * REGIONAL ENDPOINT. The `gcloud model-armor` surface talks to the global
#     endpoint and returns PERMISSION_DENIED even for project owners. The
#     regional REST endpoint (modelarmor.<region>.rep.googleapis.com) works —
#     it's the same one proxy.js uses — so we call it directly.
#
# Usage:  ./setup-redaction.sh
#
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
set -a
# shellcheck source=/dev/null
source "$DIR/app/.env"
set +a

PROJECT="${GOOGLE_CLOUD_PROJECT:?GOOGLE_CLOUD_PROJECT not set in app/.env}"

# The DLP templates MUST live in the same region as the Model Armor template
# that references them. Reuse the region from the existing template.
REGION="$(sed -E 's#.*/locations/([^/]+)/.*#\1#' <<<"${MODEL_ARMOR_TEMPLATE:-}")"
REGION="${REGION:-us-central1}"

INSPECT_ID="securebank-inspect"
DEID_ID="securebank-deidentify"
ARMOR_ID="securebank-redact"

echo "Project : $PROJECT"
echo "Region  : $REGION"
echo ""

echo "① Enabling APIs…"
gcloud services enable dlp.googleapis.com modelarmor.googleapis.com --project="$PROJECT"

TOKEN="$(gcloud auth print-access-token)"
DLP="https://dlp.googleapis.com/v2/projects/$PROJECT/locations/$REGION"
ARMOR="https://modelarmor.$REGION.rep.googleapis.com/v1/projects/$PROJECT/locations/$REGION"

# POST helper: dies on any error, but treats ALREADY_EXISTS as success so the
# script is safe to re-run.
post() {
  local url="$1" body="$2" label="$3" resp
  resp="$(curl -sS -X POST "$url" \
    -H "Authorization: Bearer $TOKEN" \
    -H "x-goog-user-project: $PROJECT" \
    -H "Content-Type: application/json" \
    -d "$body")"

  if grep -q '"error"' <<<"$resp"; then
    if grep -qE 'ALREADY_EXISTS|already exists' <<<"$resp"; then
      echo "   ✓ $label already exists — reusing it"
      return 0
    fi
    echo "   ✗ $label FAILED:" >&2
    python3 -c 'import json,sys; print("     " + json.load(sys.stdin)["error"]["message"])' <<<"$resp" >&2 \
      || echo "$resp" >&2
    exit 1
  fi
  echo "   ✓ $label created"
}

# ---------------------------------------------------------------------------
# ② Inspect template — the infoTypes we want found.
#    NOTE: every infoType used in the de-identify template below MUST appear
#    here, or Model Armor rejects the pairing.
# ---------------------------------------------------------------------------
echo "② Creating DLP inspect template…"
post "$DLP/inspectTemplates" '{
  "templateId": "'"$INSPECT_ID"'",
  "inspectTemplate": {
    "displayName": "SecureBank demo — inspect",
    "inspectConfig": {
      "infoTypes": [
        {"name": "EMAIL_ADDRESS"},
        {"name": "PHONE_NUMBER"},
        {"name": "CREDIT_CARD_NUMBER"},
        {"name": "PERSON_NAME"}
      ],
      "minLikelihood": "POSSIBLE",
      "includeQuote": true
    }
  }
}' "inspect template"

# ---------------------------------------------------------------------------
# ③ De-identify template — replace each match with a literal token.
#    Explicit replaceConfig (rather than replaceWithInfoTypeConfig) so the
#    output is exactly [EMAIL_ADDRESS] etc. — the format slide 14 renders.
# ---------------------------------------------------------------------------
echo "③ Creating DLP de-identify template…"
post "$DLP/deidentifyTemplates" '{
  "templateId": "'"$DEID_ID"'",
  "deidentifyTemplate": {
    "displayName": "SecureBank demo — de-identify",
    "deidentifyConfig": {
      "infoTypeTransformations": {
        "transformations": [
          {
            "infoTypes": [{"name": "EMAIL_ADDRESS"}],
            "primitiveTransformation": {
              "replaceConfig": {"newValue": {"stringValue": "[EMAIL_ADDRESS]"}}
            }
          },
          {
            "infoTypes": [{"name": "PHONE_NUMBER"}],
            "primitiveTransformation": {
              "replaceConfig": {"newValue": {"stringValue": "[PHONE_NUMBER]"}}
            }
          },
          {
            "infoTypes": [{"name": "CREDIT_CARD_NUMBER"}],
            "primitiveTransformation": {
              "replaceConfig": {"newValue": {"stringValue": "[CREDIT_CARD_NUMBER]"}}
            }
          },
          {
            "infoTypes": [{"name": "PERSON_NAME"}],
            "primitiveTransformation": {
              "replaceConfig": {"newValue": {"stringValue": "[PERSON_NAME]"}}
            }
          }
        ]
      }
    }
  }
}' "de-identify template"

# ---------------------------------------------------------------------------
# ④ Model Armor template wired to both DLP templates.
# ---------------------------------------------------------------------------
echo "④ Creating Model Armor template with advanced SDP…"
post "$ARMOR/templates?template_id=$ARMOR_ID" '{
  "filterConfig": {
    "sdpSettings": {
      "advancedConfig": {
        "inspectTemplate": "projects/'"$PROJECT"'/locations/'"$REGION"'/inspectTemplates/'"$INSPECT_ID"'",
        "deidentifyTemplate": "projects/'"$PROJECT"'/locations/'"$REGION"'/deidentifyTemplates/'"$DEID_ID"'"
      }
    }
  }
}' "Model Armor redact template"

echo ""
echo "✅ Done. Add this line to app/.env, then re-run ./start.sh:"
echo ""
echo "MODEL_ARMOR_TEMPLATE_REDACT=projects/$PROJECT/locations/$REGION/templates/$ARMOR_ID"
echo ""
echo "Verify with:"
echo "  curl -s localhost:3001/health | grep redactConfigured"
