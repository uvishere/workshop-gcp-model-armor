#!/usr/bin/env bash
#
# Deploys the DevFest Manila deck ("Your AI App Is Secure... Are you sure?")
# as its own Cloud Run service, next to securebank-talk. Same proxy, same
# service account, its own password.
#
#   ./presentation/deploy-devfest-manila.sh
#
# One instance, so the observability demo's event list (kept in memory)
# always shows every verdict from the talk.
#
set -euo pipefail
DECK=devfest-manila.html \
DECK_SERVICE=devfest-manila-talk \
DECK_SECRET=devfest-manila-talk-password \
DECK_MAX_INSTANCES=1 \
  exec "$(dirname "$0")/deploy.sh"
