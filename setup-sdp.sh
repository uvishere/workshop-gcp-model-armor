#!/usr/bin/env bash
#
# Workshop Step 06: Sensitive Data Protection.
#
# Scans SecureBank's document bucket for PII and writes a de-identified copy
# to a second bucket. The bot is then pointed at the clean copy, so customer
# names, emails, phones and card numbers never reach the model at all.
#
# Creates (all in one region, because the DLP job, its templates and the
# Model Armor template that reuses them in Step 07 must share a region):
#   1. a DLP inspect template     (what to look for)
#   2. a DLP de-identify template (what to replace it with)
#   3. the output bucket          <project>-securebank-docs-clean
#   4. a DLP job that inspects the docs bucket and writes masked copies
#
# Gotcha this script works around:
#
#   * QUOTA PROJECT. `gcloud auth print-access-token` returns a *user* credential
#     with no quota project attached, so DLP returns 403 "requires a quota
#     project". Every call below sends an explicit x-goog-user-project header.
#
# Usage:  ./setup-sdp.sh        (safe to re-run)
#
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
set -a
# shellcheck source=/dev/null
source "$DIR/app/.env"
set +a

PROJECT="${GOOGLE_CLOUD_PROJECT:?GOOGLE_CLOUD_PROJECT not set in app/.env}"
REGION="${GOOGLE_CLOUD_LOCATION:-us-central1}"
SOURCE_BUCKET="${PROJECT}-securebank-docs"
CLEAN_BUCKET="${PROJECT}-securebank-docs-clean"

INSPECT_ID="securebank-inspect"
DEID_ID="securebank-deidentify"
TIMEOUT_SECONDS=600

echo "Project : $PROJECT"
echo "Region  : $REGION"
echo "Source  : gs://$SOURCE_BUCKET"
echo "Output  : gs://$CLEAN_BUCKET"
echo ""

echo "① Enabling the Sensitive Data Protection API…"
gcloud services enable dlp.googleapis.com --project="$PROJECT"

TOKEN="$(gcloud auth print-access-token)"
DLP="https://dlp.googleapis.com/v2/projects/$PROJECT/locations/$REGION"

# Sends a DLP request and prints the JSON response. Dies on any error, but
# treats ALREADY_EXISTS (DLP words it "already in use") as success so the script is safe to re-run.
dlp() {
  local method="$1" url="$2" body="${3:-}" label="${4:-request}" resp
  resp="$(curl -sS -X "$method" "$url" \
    -H "Authorization: Bearer $TOKEN" \
    -H "x-goog-user-project: $PROJECT" \
    -H "Content-Type: application/json" \
    ${body:+-d "$body"})"

  if grep -q '"error"' <<<"$resp"; then
    if grep -qE 'ALREADY_EXISTS|already exists|already in use' <<<"$resp"; then
      echo "   ✓ $label already exists, reusing it" >&2
      return 0
    fi
    echo "   ✗ $label FAILED:" >&2
    python3 -c 'import json,sys; print("     " + json.load(sys.stdin)["error"]["message"])' <<<"$resp" >&2 \
      || echo "$resp" >&2
    exit 1
  fi
  printf '%s' "$resp"
}

if ! gcloud storage buckets describe "gs://$SOURCE_BUCKET" --project "$PROJECT" >/dev/null 2>&1; then
  echo "❌ gs://$SOURCE_BUCKET does not exist. Run ./setup-docs-bucket.sh first." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# ② Inspect template: the infoTypes we want found.
#    Every infoType used in the de-identify template below MUST appear here:
#    you cannot replace something you never looked for.
#    Model Armor reuses this pair in Step 07 (advanced SDP).
# ---------------------------------------------------------------------------
echo "② Creating DLP inspect template…"
dlp POST "$DLP/inspectTemplates" '{
  "templateId": "'"$INSPECT_ID"'",
  "inspectTemplate": {
    "displayName": "SecureBank workshop: inspect",
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
}' "inspect template" >/dev/null
echo "   ✓ inspect template ready"

# ---------------------------------------------------------------------------
# ③ De-identify template: replace each match with a literal token.
#    Explicit replaceConfig so the output reads [EMAIL_ADDRESS] etc.
#    No recordTransformations: this template is used on free text files.
# ---------------------------------------------------------------------------
echo "③ Creating DLP de-identify template…"
transformation() {
  printf '{"infoTypes":[{"name":"%s"}],"primitiveTransformation":{"replaceConfig":{"newValue":{"stringValue":"[%s]"}}}}' "$1" "$1"
}
dlp POST "$DLP/deidentifyTemplates" '{
  "templateId": "'"$DEID_ID"'",
  "deidentifyTemplate": {
    "displayName": "SecureBank workshop: de-identify",
    "deidentifyConfig": {
      "infoTypeTransformations": {
        "transformations": [
          '"$(transformation EMAIL_ADDRESS)"',
          '"$(transformation PHONE_NUMBER)"',
          '"$(transformation CREDIT_CARD_NUMBER)"',
          '"$(transformation PERSON_NAME)"'
        ]
      }
    }
  }
}' "de-identify template" >/dev/null
echo "   ✓ de-identify template ready"

# ---------------------------------------------------------------------------
# ④ Output bucket. DLP refuses to write into the bucket it is reading, and
#    a re-run should not mix old masked files with new ones, so it is emptied.
# ---------------------------------------------------------------------------
echo "④ Preparing gs://$CLEAN_BUCKET…"
if ! gcloud storage buckets describe "gs://$CLEAN_BUCKET" --project "$PROJECT" >/dev/null 2>&1; then
  gcloud storage buckets create "gs://$CLEAN_BUCKET" \
    --project "$PROJECT" \
    --location "$REGION" \
    --uniform-bucket-level-access \
    --public-access-prevention
else
  gcloud storage rm "gs://$CLEAN_BUCKET/**" --project "$PROJECT" >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# ⑤ The DLP job: inspect every file in the source bucket, write a masked
#    copy of each into the clean bucket. The copy is written by the DLP
#    service agent, not by you, which is why it needs no extra setup when
#    everything lives in the same project.
# ---------------------------------------------------------------------------
echo "⑤ Starting the de-identification job…"
JOB_JSON="$(dlp POST "$DLP/dlpJobs" '{
  "inspectJob": {
    "storageConfig": {
      "cloudStorageOptions": {
        "fileSet": {"url": "gs://'"$SOURCE_BUCKET"'/**"},
        "fileTypes": ["TEXT_FILE"]
      }
    },
    "inspectTemplateName": "projects/'"$PROJECT"'/locations/'"$REGION"'/inspectTemplates/'"$INSPECT_ID"'",
    "actions": [{
      "deidentify": {
        "cloudStorageOutput": "gs://'"$CLEAN_BUCKET"'",
        "fileTypesToTransform": ["TEXT_FILE"],
        "transformationConfig": {
          "deidentifyTemplate": "projects/'"$PROJECT"'/locations/'"$REGION"'/deidentifyTemplates/'"$DEID_ID"'"
        }
      }
    }]
  }
}' "DLP job")"
JOB_NAME="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])' <<<"$JOB_JSON")"
echo "   ✓ $JOB_NAME"

# Jobs queue before they run, so a minute or two of PENDING is normal.
DEADLINE=$(( $(date +%s) + TIMEOUT_SECONDS ))
while :; do
  JOB_JSON="$(dlp GET "https://dlp.googleapis.com/v2/$JOB_NAME" "" "job status")"
  STATE="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("state",""))' <<<"$JOB_JSON")"
  echo "   … $STATE"
  case "$STATE" in
    DONE) break ;;
    FAILED|CANCELED)
      echo "❌ Job $STATE:" >&2
      python3 -c 'import json,sys; [print("   " + e.get("details",{}).get("message","")) for e in json.load(sys.stdin).get("errors",[])]' <<<"$JOB_JSON" >&2
      exit 1 ;;
  esac
  if [ "$(date +%s)" -ge "$DEADLINE" ]; then
    echo "⏱  Still $STATE after $((TIMEOUT_SECONDS / 60)) minutes. The job keeps running in the background." >&2
    echo "   Watch it in the console: Security > Sensitive Data Protection > Inspection > Inspect jobs," >&2
    echo "   then re-run this script, or continue once it shows Done." >&2
    exit 1
  fi
  sleep 10
done

echo ""
echo "Findings:"
python3 - "$JOB_JSON" <<'PY'
import json, sys
stats = json.loads(sys.argv[1]).get("inspectDetails", {}).get("result", {}).get("infoTypeStats", [])
if not stats:
    print("   (none reported)")
for s in sorted(stats, key=lambda s: -int(s.get("count", 0))):
    print(f"   {s['infoType']['name']:<20} {s.get('count', 0)}")
PY

echo ""
echo "Masked copies in gs://$CLEAN_BUCKET:"
gcloud storage ls -r "gs://$CLEAN_BUCKET" --project "$PROJECT"

echo ""
echo "✅ Done. Switch the running bot to the clean copy:"
echo ""
echo "  curl -s -X POST localhost:8080/api/admin/reload-docs \\"
echo "    -H \"x-admin-key: \$ADMIN_API_KEY\" -H 'Content-Type: application/json' \\"
echo "    -d '{\"bucket\": \"$CLEAN_BUCKET\"}'"
echo ""
echo "and make it stick across restarts by changing this line in app/.env:"
echo ""
echo "SECUREBANK_DOCS_BUCKET=$CLEAN_BUCKET"
